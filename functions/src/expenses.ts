import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import {AddExpenseInput, Expense} from "./types";

const db = admin.firestore();

/**
 * Водитель добавляет расход во время активного рейса.
 * Обязательные поля: сумма, категория, GPS-координаты и время.
 * Фото чека опционально — URL передаётся после загрузки в Storage.
 */
export const addExpense = functions.https.onCall(
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

    const input = request.data as AddExpenseInput & {
      receiptUrl?: string;
    };

    if (
      !input.tripId ||
      !input.amount ||
      !input.category ||
      !input.latitude ||
      !input.longitude
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Обязательные поля: tripId, amount, category, latitude, longitude"
      );
    }

    if (typeof input.amount !== "number" || input.amount <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Сумма должна быть положительным числом"
      );
    }

    const validCategories = [
      "fuel",
      "parking",
      "repair",
      "toll",
      "washing",
      "tires",
      "insurance",
      "other",
    ];

    if (!validCategories.includes(input.category)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Недопустимая категория. Допустимые: ${validCategories.join(", ")}`
      );
    }

    const tripRef = db.collection("trips").doc(input.tripId);
    const tripDoc = await tripRef.get();

    if (!tripDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Рейс не найден");
    }

    const trip = tripDoc.data();
    if (!trip || trip.status !== "active") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Можно добавлять расходы только к активному рейсу"
      );
    }

    if (trip.driverId !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Вы можете добавлять расходы только к своим рейсам"
      );
    }

    const now = Timestamp.now();
    const expenseRef = db.collection("expenses").doc();

    const expense: Expense = {
      id: expenseRef.id,
      tripId: input.tripId,
      driverId: uid,
      amount: input.amount,
      category: input.category,
      description: input.description,
      receiptUrl: input.receiptUrl,
      location: {
        latitude: input.latitude,
        longitude: input.longitude,
      },
      photoTimestamp: now,
      createdAt: now,
    };

    await expenseRef.set(expense);

    functions.logger.info("Добавлен расход", {
      expenseId: expenseRef.id,
      tripId: input.tripId,
      amount: input.amount,
      category: input.category,
    });

    return {
      expenseId: expenseRef.id,
      amount: input.amount,
      category: input.category,
      createdAt: now.toDate().toISOString(),
    };
  }
);

/**
 * Получение всех расходов для конкретного рейса.
 */
export const getTripExpenses = functions.https.onCall(
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
    if (!tripId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не указан tripId"
      );
    }

    const tripDoc = await db.collection("trips").doc(tripId).get();
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Рейс не найден");
    }

    const trip = tripDoc.data();
    if (!trip) {
      throw new functions.https.HttpsError("not-found", "Рейс не найден");
    }

    const isOwner = await checkIsOwner(uid);
    if (!isOwner && trip.driverId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Нет доступа");
    }

    const snapshot = await db
      .collection("expenses")
      .where("tripId", "==", tripId)
      .orderBy("createdAt", "desc")
      .get();

    const expenses = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString?.() || data.createdAt,
        photoTimestamp:
          data.photoTimestamp?.toDate?.()?.toISOString?.() || data.photoTimestamp,
      };
    });

    const total = expenses.reduce(
      (sum, exp) => sum + (exp.amount as number),
      0
    );

    return {expenses, total, count: expenses.length};
  }
);

/**
 * Вспомогательная: проверка что пользователь — owner.
 */
async function checkIsOwner(uid: string): Promise<boolean> {
  const ownerDoc = await db.collection("owners").doc(uid).get();
  return ownerDoc.exists && ownerDoc.data()?.role === "owner";
}

/**
 * Получение расходов водителя за период (для владельца).
 */
export const getDriverExpensesReport = functions.https.onCall(
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

    if (!(await checkIsOwner(uid))) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Только для владельца"
      );
    }

    const driverId = request.data.driverId as string;
    const startDate = new Date(request.data.startDate as string);
    const endDate = new Date(request.data.endDate as string);

    if (!driverId || isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Укажите driverId, startDate, endDate"
      );
    }

    const snapshot = await db
      .collection("expenses")
      .where("driverId", "==", driverId)
      .where("createdAt", ">=", Timestamp.fromDate(startDate))
      .where("createdAt", "<=", Timestamp.fromDate(endDate))
      .orderBy("createdAt", "desc")
      .get();

    const expenses = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString?.() || data.createdAt,
      };
    });

    const total = expenses.reduce(
      (sum, exp) => sum + (exp.amount as number),
      0
    );

    const byCategory: Record<string, number> = {};
    for (const exp of expenses) {
      const cat = exp.category as string;
      byCategory[cat] = (byCategory[cat] || 0) + (exp.amount as number);
    }

    return {expenses, total, byCategory, count: expenses.length};
  }
);
