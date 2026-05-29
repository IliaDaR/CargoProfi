import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Timestamp, FieldValue} from "firebase-admin/firestore";
import {
  StartTripInput,
  AddTrackPointInput,
  EndTripInput,
  Trip,
  GeoPoint,
} from "./types";
import {calculateTotalDistance} from "./distance";

const db = admin.firestore();

/**
 * Водитель начинает рейс.
 * Фиксируются время старта и GPS-координаты.
 * Создаётся документ в коллекции trips со статусом "active".
 */
export const startTrip = functions.https.onCall(
  {
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Пользователь не аутентифицирован"
      );
    }

    const input = request.data as StartTripInput;

    if (!input.vehicleId || !input.latitude || !input.longitude) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не указаны обязательные поля: vehicleId, latitude, longitude"
      );
    }

    const driverDoc = await db.collection("drivers").doc(uid).get();
    if (!driverDoc.exists || driverDoc.data()?.role !== "driver") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Только водитель может начинать рейс"
      );
    }

    const vehicleDoc = await db
      .collection("vehicles")
      .doc(input.vehicleId)
      .get();
    if (!vehicleDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Транспортное средство не найдено"
      );
    }

    const activeTrips = await db
      .collection("trips")
      .where("driverId", "==", uid)
      .where("status", "==", "active")
      .limit(1)
      .get();

    if (!activeTrips.empty) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "У вас уже есть активный рейс. Завершите его перед началом нового."
      );
    }

    const now = Timestamp.now();
    const startPoint: GeoPoint = {
      latitude: input.latitude,
      longitude: input.longitude,
      timestamp: now,
    };

    const tripRef = db.collection("trips").doc();
    const trip: Trip = {
      id: tripRef.id,
      driverId: uid,
      vehicleId: input.vehicleId,
      status: "active",
      startTime: now,
      startLocation: {
        latitude: input.latitude,
        longitude: input.longitude,
      },
      track: [startPoint],
      mileage: 0,
      mileageSource: "auto",
      cargoDescription: input.cargoDescription,
      routeDescription: input.routeDescription,
      createdAt: now,
      updatedAt: now,
    };

    await tripRef.set(trip);

    functions.logger.info("Рейс начат", {tripId: tripRef.id, driverId: uid});

    return {
      tripId: tripRef.id,
      startTime: now.toDate().toISOString(),
      startLocation: {
        latitude: input.latitude,
        longitude: input.longitude,
      },
    };
  }
);

/**
 * Добавление GPS-точки в массив track[] активного рейса.
 * Вызывается водителем периодически (раз в минуту).
 */
export const addTrackPoint = functions.https.onCall(
  {
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Пользователь не аутентифицирован"
      );
    }

    const input = request.data as AddTrackPointInput;

    if (!input.tripId || !input.latitude || !input.longitude) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не указаны обязательные поля: tripId, latitude, longitude"
      );
    }

    const tripRef = db.collection("trips").doc(input.tripId);
    const tripDoc = await tripRef.get();

    if (!tripDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Рейс не найден");
    }

    const trip = tripDoc.data() as Trip;

    if (trip.driverId !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Вы можете обновлять только свои рейсы"
      );
    }

    if (trip.status !== "active") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Рейс неактивен"
      );
    }

    const now = Timestamp.now();
    const newPoint: GeoPoint = {
      latitude: input.latitude,
      longitude: input.longitude,
      timestamp: now,
    };

    await tripRef.update({
      track: FieldValue.arrayUnion(newPoint),
      updatedAt: now,
    });

    return {
      success: true,
      trackLength: (trip.track?.length || 0) + 1,
    };
  }
);

/**
 * Батчевое добавление нескольких GPS-точек.
 * Используется для отправки накопленных данных для экономии трафика.
 */
export const addTrackPointsBatch = functions.https.onCall(
  {
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Пользователь не аутентифицирован"
      );
    }

    const tripId = request.data.tripId as string;
    const points = request.data.points as Array<{
      latitude: number;
      longitude: number;
      timestamp?: string;
    }>;

    if (!tripId || !points || !Array.isArray(points) || points.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не указаны tripId или массив points"
      );
    }

    const tripRef = db.collection("trips").doc(tripId);
    const tripDoc = await tripRef.get();

    if (!tripDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Рейс не найден");
    }

    const trip = tripDoc.data() as Trip;

    if (trip.driverId !== uid || trip.status !== "active") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Нельзя обновить этот рейс"
      );
    }

    const batch = db.batch();
    const now = Timestamp.now();

    for (const pt of points) {
      const newPoint: GeoPoint = {
        latitude: pt.latitude,
        longitude: pt.longitude,
        timestamp: pt.timestamp ? Timestamp.fromDate(new Date(pt.timestamp)) : now,
      };
      batch.update(tripRef, {
        track: FieldValue.arrayUnion(newPoint),
        updatedAt: now,
      });
    }

    await batch.commit();

    return {success: true, added: points.length};
  }
);

/**
 * Завершение рейса.
 * Рассчитывает пробег автоматически по GPS-треку, либо использует
 * значение переданное вручную водителем.
 * Приоритет: авто-расчёт если track не пуст.
 */
export const endTrip = functions.https.onCall(
  {
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Пользователь не аутентифицирован"
      );
    }

    const input = request.data as EndTripInput;

    if (!input.tripId || !input.latitude || !input.longitude) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не указаны обязательные поля: tripId, latitude, longitude"
      );
    }

    const tripRef = db.collection("trips").doc(input.tripId);
    const tripDoc = await tripRef.get();

    if (!tripDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Рейс не найден");
    }

    const trip = tripDoc.data() as Trip;

    if (trip.driverId !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Вы можете завершать только свои рейсы"
      );
    }

    if (trip.status !== "active") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Рейс уже завершён или отменён"
      );
    }

    const now = Timestamp.now();

    // Добавляем конечную точку в трек
    const endPoint: GeoPoint = {
      latitude: input.latitude,
      longitude: input.longitude,
      timestamp: now,
    };

    const finalTrack = [...(trip.track || []), endPoint];

    // Определяем пробег
    let mileage: number;
    let mileageSource: "auto" | "manual";

    const autoMileage = calculateTotalDistance(finalTrack);

    if (autoMileage > 0) {
      mileage = autoMileage;
      mileageSource = "auto";
    } else if (input.manualMileage && input.manualMileage > 0) {
      mileage = input.manualMileage;
      mileageSource = "manual";
    } else {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не удалось рассчитать пробег. Укажите пробег вручную."
      );
    }

    const updateData: Partial<Trip> & { [key: string]: unknown } = {
      status: "completed",
      endTime: now,
      endLocation: {
        latitude: input.latitude,
        longitude: input.longitude,
      },
      track: finalTrack,
      mileage,
      mileageSource,
      updatedAt: now,
    };

    if (input.income !== undefined) {
      updateData.income = input.income;
    }
    if (input.manualMileage !== undefined && mileageSource === "manual") {
      updateData.manualMileage = input.manualMileage;
    }

    await tripRef.update(updateData);

    functions.logger.info("Рейс завершён", {
      tripId: tripRef.id,
      mileage,
      mileageSource,
    });

    return {
      tripId: tripRef.id,
      mileage,
      mileageSource,
      endTime: now.toDate().toISOString(),
      endLocation: {
        latitude: input.latitude,
        longitude: input.longitude,
      },
    };
  }
);

/**
 * Получение списка рейсов для водителя.
 */
export const getMyTrips = functions.https.onCall(
  {
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Пользователь не аутентифицирован"
      );
    }

    const limit = request.data.limit as number || 20;
    const status = request.data.status as string | undefined;

    let query: FirebaseFirestore.Query = db
      .collection("trips")
      .where("driverId", "==", uid)
      .orderBy("startTime", "desc");

    if (status && (status === "active" || status === "completed")) {
      query = query.where("status", "==", status);
    }

    const snapshot = await query.limit(limit).get();

    const trips = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        ...data,
        startTime: data.startTime?.toDate?.()?.toISOString?.() || data.startTime,
        endTime: data.endTime?.toDate?.()?.toISOString?.() || data.endTime,
        createdAt: data.createdAt?.toDate?.()?.toISOString?.() || data.createdAt,
      };
    });

    return {trips, count: trips.length};
  }
);
