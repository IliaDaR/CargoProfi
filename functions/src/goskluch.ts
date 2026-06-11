import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {Timestamp} from "firebase-admin/firestore";
import {checkIsOwner} from "./auth";

const db = admin.firestore();

interface SignWaybillResponse {
  success: boolean;
  signatureUrl?: string;
  signedPdfUrl?: string;
  error?: string;
  staging?: boolean;
}

export const signWaybill = functions.https.onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 90,
    memory: "512MiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError("unauthenticated", "Не аутентифицирован");
    }

    if (!(await checkIsOwner(uid))) {
      throw new functions.https.HttpsError("permission-denied", "Только владелец может подписывать");
    }

    const tripId = request.data.tripId as string;
    if (!tripId) {
      throw new functions.https.HttpsError("invalid-argument", "Не указан tripId");
    }

    const tripDoc = await db.collection("trips").doc(tripId).get();
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Рейс не найден");
    }

    const trip = tripDoc.data()!;
    if (trip.status !== "completed") {
      throw new functions.https.HttpsError("failed-precondition", "Подписать можно только завершённый рейс");
    }

    if (!trip.waybillUrl) {
      throw new functions.https.HttpsError("failed-precondition", "Сначала сформируйте путевой лист");
    }

    if (trip.signatureStatus === "signed") {
      return {success: true, signatureUrl: trip.signatureUrl, signedPdfUrl: trip.signedPdfUrl, alreadySigned: true};
    }

    try {
      // 1. Скачиваем PDF из Storage
      const bucket = admin.storage().bucket();
      const filePath = `waybills/${uid}/${tripId}.pdf`;
      const file = bucket.file(filePath);

      const [exists] = await file.exists();
      if (!exists) {
        throw new Error("Файл PDF не найден в хранилище");
      }

      const [pdfBuffer] = await file.download();

      // 2. SHA-256 хэш
      const hash = crypto.createHash("sha256").update(pdfBuffer).digest("hex");

      // 3. Отправка в Госключ
      const goskluchResult = await callGoskluchAPI(hash, uid, tripId);

      if (!goskluchResult.success) {
        throw new Error(goskluchResult.error || "Ошибка Госключа");
      }

      const now = Timestamp.now();

      // Если Госключ вернул подписанный PDF — используем его URL напрямую
      const signedPdfUrl = goskluchResult.signedPdfUrl || undefined;

      await tripDoc.ref.update({
        signatureStatus: "signed",
        signatureUrl: goskluchResult.signatureUrl || null,
        signatureHash: hash,
        signedPdfUrl: signedPdfUrl || null,
        signedAt: now,
        signedBy: uid,
        updatedAt: now,
      });

      functions.logger.info("Путевой лист подписан", {tripId, hash});

      return {
        success: true,
        signatureUrl: goskluchResult.signatureUrl,
        signedPdfUrl,
        hash,
      };
    } catch (err: any) {
      functions.logger.error("signWaybill error", err);
      throw new functions.https.HttpsError("internal", err.message || "Ошибка подписания");
    }
  }
);

async function callGoskluchAPI(
  hash: string,
  ownerId: string,
  documentId: string
): Promise<SignWaybillResponse> {
  const apiUrl = process.env.GOSKLUCH_API_URL;
  const apiKey = process.env.GOSKLUCH_API_KEY;

  if (!apiUrl || !apiKey) {
    functions.logger.info("Госключ API не настроен — работаем в режиме заглушки");
    return {
      success: true,
      signatureUrl: `https://numino.ru/check?id=${documentId}&sig=mock`,
      staging: true,
    };
  }

  try {
    const response = await fetch(apiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        hash,
        ownerId,
        documentId,
        algorithm: "GOST3410-2012-256",
        encoding: "base64",
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      return {success: false, error: `Госключ API: ${response.status} — ${err}`};
    }

    const data = await response.json();
    return {
      success: true,
      signatureUrl: data.signature,
      signedPdfUrl: data.signedPdfUrl,
    };
  } catch (err: any) {
    functions.logger.error("Goskluch API error", err);
    return {success: false, error: err.message || "Сеть недоступна"};
  }
}
