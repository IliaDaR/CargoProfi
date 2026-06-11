import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {Timestamp} from "firebase-admin/firestore";

const db = admin.firestore();

export async function notifyOwner(
  ownerId: string,
  title: string,
  body: string,
  type: string,
  metadata?: Record<string, string>
): Promise<void> {
  try {
    await db.collection("notifications").add({
      ownerId,
      title,
      body,
      type,
      metadata: metadata || {},
      read: false,
      createdAt: Timestamp.now(),
    });
  } catch (err) {
    // Non-critical — log and continue
    console.error("notifyOwner failed", err);
  }
}

export async function notifyTripStarted(
  ownerId: string, driverName: string, tripId: string
): Promise<void> {
  await notifyOwner(ownerId, "Рейс начат", `Водитель ${driverName} начал рейс`, "trip_start", {tripId});
}

export async function notifyTripCompleted(
  ownerId: string, driverName: string, tripId: string, mileage: number
): Promise<void> {
  await notifyOwner(ownerId, "Рейс завершён", `Водитель ${driverName}: ${mileage.toFixed(1)} км`, "trip_end", {tripId});
}

export async function notifyHighExpense(
  ownerId: string, driverName: string, amount: number, category: string
): Promise<void> {
  await notifyOwner(ownerId, "Крупный расход", `${driverName}: ${amount} ₽ (${category})`, "warning", {amount: String(amount)});
}

export const getOwnerNotifications = functions.https.onCall(
  {enforceAppCheck: true},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Не аутентифицирован");

    const unreadOnly = request.data.unreadOnly !== false;
    const limit = Math.min(request.data.limit as number || 50, 100);

    let query = db.collection("notifications")
      .where("ownerId", "==", uid)
      .orderBy("createdAt", "desc")
      .limit(limit);

    if (unreadOnly) {
      query = query.where("read", "==", false);
    }

    const snapshot = await query.get();
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString?.() || null,
    }));

    return {notifications, count: notifications.length};
  }
);

export const markNotificationRead = functions.https.onCall(
  {enforceAppCheck: true},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Не аутентифицирован");

    const notificationId = request.data.id as string;
    if (!notificationId) throw new functions.https.HttpsError("invalid-argument", "id required");

    const doc = await db.collection("notifications").doc(notificationId).get();
    if (!doc.exists || doc.data()?.ownerId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Нет доступа");
    }

    await doc.ref.update({read: true});
    return {success: true};
  }
);
