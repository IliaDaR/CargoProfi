import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import {CalculateSalaryInput, Trip, SalaryRule, SalaryPayment} from "./types";

const db = admin.firestore();

/**
 * Автоматический расчёт зарплаты водителя за выбранный период.
 * Только для владельца парка.
 *
 * Логика:
 * 1. Ищем активное правило зарплаты для водителя.
 * 2. Собираем все завершённые рейсы водителя за период.
 * 3. Если правило "percent" — зарплата = сумма(доход рейса) * percentValue / 100
 * 4. Если правило "fixed" — зарплата = количество рейсов * fixedValue
 * 5. Сохраняем результат в salaryPayments.
 */
export const calculateSalary = functions.https.onCall(
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

    const ownerDoc = await db.collection("owners").doc(uid).get();
    if (!ownerDoc.exists || ownerDoc.data()?.role !== "owner") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Только владелец может рассчитывать зарплату"
      );
    }

    const input = request.data as CalculateSalaryInput;

    if (!input.driverId || !input.periodStart || !input.periodEnd) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Укажите driverId, periodStart, periodEnd"
      );
    }

    const startDate = new Date(input.periodStart);
    const endDate = new Date(input.periodEnd);

    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Неверный формат дат. Используйте ISO 8601 (YYYY-MM-DD)"
      );
    }

    if (startDate >= endDate) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "periodStart должен быть раньше periodEnd"
      );
    }

    // Проверяем что водитель принадлежит владельцу
    const driverDoc = await db.collection("drivers").doc(input.driverId).get();
    if (!driverDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Водитель не найден");
    }

    const driverData = driverDoc.data();
    if (driverData?.ownerId !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Водитель не принадлежит вашему парку"
      );
    }

    // Ищем активное правило
    const ruleSnapshot = await db
      .collection("salaryRules")
      .where("ownerId", "==", uid)
      .where("driverId", "==", input.driverId)
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (ruleSnapshot.empty) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Не задано правило начисления зарплаты для этого водителя. " +
          "Сначала задайте правило через setSalaryRule."
      );
    }

    const rule = ruleSnapshot.docs[0].data() as SalaryRule;

    // Собираем завершённые рейсы за период
    const tripsSnapshot = await db
      .collection("trips")
      .where("driverId", "==", input.driverId)
      .where("status", "==", "completed")
      .where("startTime", ">=", Timestamp.fromDate(startDate))
      .where("startTime", "<=", Timestamp.fromDate(endDate))
      .orderBy("startTime", "asc")
      .get();

    const trips = tripsSnapshot.docs.map((doc) => doc.data() as Trip);

    if (trips.length === 0) {
      return {
        periodStart: input.periodStart,
        periodEnd: input.periodEnd,
        driverId: input.driverId,
        tripsCount: 0,
        totalIncome: 0,
        calculatedSalary: 0,
        ruleType: rule.type,
        ruleValue: 0,
        message: "Нет завершённых рейсов за выбранный период",
      };
    }

    let totalIncome = 0;
    let calculatedSalary = 0;

    for (const trip of trips) {
      const income = trip.income || 0;
      totalIncome += income;
    }

    if (rule.type === "percent") {
      const percentValue = rule.percentValue || 0;
      calculatedSalary = Math.round((totalIncome * percentValue) / 100);
    } else if (rule.type === "fixed") {
      const fixedValue = rule.fixedValue || 0;
      calculatedSalary = trips.length * fixedValue;
    }

    const tripIds = trips.map((t) => t.id);

    const paymentRef = db.collection("salaryPayments").doc();
    const now = Timestamp.now();

    const payment: SalaryPayment = {
      id: paymentRef.id,
      ownerId: uid,
      driverId: input.driverId,
      periodStart: Timestamp.fromDate(startDate),
      periodEnd: Timestamp.fromDate(endDate),
      tripIds,
      totalIncome,
      calculatedSalary,
      ruleType: rule.type,
      ruleValue: rule.type === "percent" ? (rule.percentValue || 0) : (rule.fixedValue || 0),
      status: "calculated",
      createdAt: now,
    };

    await paymentRef.set(payment);

    functions.logger.info("Зарплата рассчитана", {
      paymentId: paymentRef.id,
      driverId: input.driverId,
      calculatedSalary,
      tripsCount: trips.length,
    });

    return {
      paymentId: paymentRef.id,
      driverId: input.driverId,
      periodStart: input.periodStart,
      periodEnd: input.periodEnd,
      tripsCount: trips.length,
      totalIncome,
      calculatedSalary,
      ruleType: rule.type,
      ruleValue: rule.type === "percent" ? rule.percentValue : rule.fixedValue,
      status: "calculated",
    };
  }
);

/**
 * Получение истории расчётов зарплаты для водителя.
 * Владелец видит все расчёты. Водитель видит только свои.
 */
export const getSalaryHistory = functions.https.onCall(
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

    const driverId = (request.data.driverId as string) || uid;
    const isOwner = await checkIsOwner(uid);

    let query: FirebaseFirestore.Query = db
      .collection("salaryPayments")
      .where("driverId", "==", driverId)
      .orderBy("createdAt", "desc");

    if (!isOwner && driverId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Нет доступа");
    }

    if (isOwner) {
      query = query.where("ownerId", "==", uid);
    }

    const snapshot = await query.get();

    const payments = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString?.() || data.createdAt,
        periodStart:
          data.periodStart?.toDate?.()?.toISOString?.() || data.periodStart,
        periodEnd:
          data.periodEnd?.toDate?.()?.toISOString?.() || data.periodEnd,
        paidAt: data.paidAt?.toDate?.()?.toISOString?.() || data.paidAt,
      };
    });

    return {payments, count: payments.length};
  }
);

async function checkIsOwner(uid: string): Promise<boolean> {
  const ownerDoc = await db.collection("owners").doc(uid).get();
  return ownerDoc.exists && ownerDoc.data()?.role === "owner";
}
