import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import {SetSalaryRuleInput, SalaryRule} from "./types";

const db = admin.firestore();

/**
 * Владелец задаёт правило начисления зарплаты для водителя.
 * type = "percent" — процент от дохода каждого рейса (percentValue)
 * type = "fixed"  — фиксированная сумма за каждый рейс (fixedValue)
 */
export const setSalaryRule = functions.https.onCall(
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
        "Только владелец может задавать правила зарплаты"
      );
    }

    const input = request.data as SetSalaryRuleInput;

    if (!input.driverId || !input.type) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не указаны driverId и/или type"
      );
    }

    if (!["percent", "fixed"].includes(input.type)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "type должен быть 'percent' или 'fixed'"
      );
    }

    if (input.type === "percent" && (!input.percentValue || input.percentValue <= 0 || input.percentValue > 100)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "percentValue должен быть в диапазоне 0–100"
      );
    }

    if (input.type === "fixed" && (!input.fixedValue || input.fixedValue <= 0)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "fixedValue должен быть положительным числом"
      );
    }

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

    const existingRules = await db
      .collection("salaryRules")
      .where("ownerId", "==", uid)
      .where("driverId", "==", input.driverId)
      .where("isActive", "==", true)
      .get();

    const batch = db.batch();
    const now = Timestamp.now();

    for (const doc of existingRules.docs) {
      batch.update(doc.ref, {isActive: false, updatedAt: now});
    }

    const ruleRef = db.collection("salaryRules").doc();
    const rule: SalaryRule = {
      id: ruleRef.id,
      ownerId: uid,
      driverId: input.driverId,
      type: input.type,
      percentValue: input.type === "percent" ? input.percentValue : undefined,
      fixedValue: input.type === "fixed" ? input.fixedValue : undefined,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };

    batch.set(ruleRef, rule);
    await batch.commit();

    functions.logger.info("Правило зарплаты создано", {
      ruleId: ruleRef.id,
      driverId: input.driverId,
      type: input.type,
    });

    return {
      ruleId: ruleRef.id,
      driverId: input.driverId,
      type: input.type,
      value: input.type === "percent" ? input.percentValue : input.fixedValue,
      createdAt: now.toDate().toISOString(),
    };
  }
);

/**
 * Получение активного правила зарплаты для водителя.
 */
export const getSalaryRule = functions.https.onCall(
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

    const driverId = request.data.driverId as string;
    if (!driverId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Не указан driverId"
      );
    }

    const driverDoc = await db.collection("drivers").doc(driverId).get();
    const isOwner = await checkIsOwner(uid);

    if (!isOwner && driverId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Нет доступа");
    }

    const ownerId = isOwner ? uid : driverDoc.data()?.ownerId;
    if (!ownerId) {
      throw new functions.https.HttpsError("not-found", "Владелец не найден");
    }

    const snapshot = await db
      .collection("salaryRules")
      .where("ownerId", "==", ownerId)
      .where("driverId", "==", driverId)
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return {rule: null};
    }

    const data = snapshot.docs[0].data();
    return {
      rule: {
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString?.() || data.createdAt,
        updatedAt: data.updatedAt?.toDate?.()?.toISOString?.() || data.updatedAt,
      },
    };
  }
);

async function checkIsOwner(uid: string): Promise<boolean> {
  const ownerDoc = await db.collection("owners").doc(uid).get();
  return ownerDoc.exists && ownerDoc.data()?.role === "owner";
}
