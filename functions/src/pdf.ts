import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import {Trip, Vehicle, DriverProfile} from "./types";

const db = admin.firestore();

/**
 * Генерация PDF путевого листа по форме, утверждённой Приказом Минтранса.
 * Доступно только владельцу парка.
 *
 * Поля, подставляемые из рейса:
 * - Дата (startTime)
 * - Госномер автомобиля (vehicle.plateNumber)
 * - Водитель (driver.displayName)
 * - Пробег (mileage)
 * - Время выезда (startTime) и возврата (endTime)
 *
 * PDF сохраняется в Firebase Storage в /waybills/{ownerId}/{tripId}.pdf
 * и доступная ссылка записывается в документ рейса.
 */
export const generateWaybill = functions.https.onCall(
  {
    enforceAppCheck: false,
    timeoutSeconds: 60,
    memory: "512MiB",
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
        "Только владелец может формировать путевые листы"
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

    const trip = tripDoc.data() as Trip;

    if (trip.status !== "completed") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Путевой лист можно сформировать только для завершённого рейса"
      );
    }

    const vehicleDoc = await db
      .collection("vehicles")
      .doc(trip.vehicleId)
      .get();
    const vehicle = vehicleDoc.exists
      ? (vehicleDoc.data() as Vehicle)
      : null;

    const driverDoc = await db
      .collection("drivers")
      .doc(trip.driverId)
      .get();
    const driver = driverDoc.exists
      ? (driverDoc.data() as DriverProfile)
      : null;

    // Динамический импорт pdfkit
    const PDFDocument = require("pdfkit");

    const pdfBuffer = await generateWaybillPdf(
      PDFDocument,
      trip,
      vehicle,
      driver
    );

    const bucket = admin.storage().bucket();
    const filePath = `waybills/${uid}/${tripId}.pdf`;
    const file = bucket.file(filePath);

    await file.save(pdfBuffer, {
      metadata: {
        contentType: "application/pdf",
      },
    });

    await file.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;

    await db.collection("trips").doc(tripId).update({
      waybillUrl: publicUrl,
      updatedAt: Timestamp.now(),
    });

    functions.logger.info("Путевой лист сгенерирован", {
      tripId,
      url: publicUrl,
    });

    return {
      success: true,
      waybillUrl: publicUrl,
      tripId,
    };
  }
);

/**
 * Генерирует PDF путевого листа в буфер.
 * Использует pdfkit для формирования документа.
 */
async function generateWaybillPdf(
  PDFDocument: typeof import("pdfkit"),
  trip: Trip,
  vehicle: Vehicle | null,
  driver: DriverProfile | null
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    try {
      const chunks: Buffer[] = [];
      const doc = new PDFDocument({
        size: "A4",
        margin: 50,
        info: {
          Title: `Путевой лист #${trip.id}`,
          Author: "Рабочий кабинет перевозчика",
        },
      });

      doc.on("data", (chunk: Buffer) => chunks.push(chunk));
      doc.on("end", () => resolve(Buffer.concat(chunks)));
      doc.on("error", reject);

      const fontPath = require.resolve("pdfkit");
      const fontDir = fontPath.replace(/[\\/]pdfkit\.js$/, "") + "/fonts";
      const regularFont = fontDir + "/Helvetica.ttf";
      const boldFont = fontDir + "/Helvetica-Bold.ttf";

      const startDate = trip.startTime.toDate();
      const endDate = trip.endTime ? trip.endTime.toDate() : new Date();

      doc.fontSize(14).text("ПУТЕВОЙ ЛИСТ ГРУЗОВОГО АВТОМОБИЛЯ", {
        align: "center",
      });
      doc.moveDown(0.5);
      doc.fontSize(12).text("(Форма утверждена Приказом Минтранса России)", {
        align: "center",
      });
      doc.moveDown(1.5);

      // --- Основные данные ---
      doc.fontSize(11);

      doc.text(
        `Дата: ${startDate.toLocaleDateString("ru-RU")}${" ".repeat(30)}Номер рейса: ${trip.id.slice(0, 8)}`
      );
      doc.moveDown(0.5);

      doc.text(
        `Государственный номер: ${vehicle?.plateNumber || "—"}`
      );
      doc.text(`Марка, модель: ${vehicle?.brand || "—"} ${vehicle?.model || ""}`);
      doc.moveDown(0.5);

      doc.text(
        `Водитель: ${driver?.displayName || "—"}${" ".repeat(20)}Удостоверение: ${driver?.licenseNumber || "—"}`
      );
      doc.moveDown(1);

      // --- Линия ---
      doc
        .moveTo(50, doc.y)
        .lineTo(545, doc.y)
        .stroke();
      doc.moveDown(1);

      // --- Режим работы ---
      doc.fontSize(11).text("РЕЖИМ РАБОТЫ:", {underline: true});
      doc.moveDown(0.3);

      doc.text(
        `Время выезда: ${formatTime(startDate)}${" ".repeat(20)}` +
        `Дата: ${startDate.toLocaleDateString("ru-RU")}`
      );
      doc.text(
        `Время возврата: ${formatTime(endDate)}${" ".repeat(20)}` +
        `Дата: ${endDate.toLocaleDateString("ru-RU")}`
      );
      doc.text(
        `Показания спидометра при выезде: ________ км${" ".repeat(10)}` +
        `Показания спидометра при возврате: ________ км`
      );
      doc.text(
        `Пробег: ${trip.mileage} км ` +
        `(${trip.mileageSource === "auto" ? "рассчитан автоматически" : "указан вручную"})`
      );
      doc.moveDown(1);

      // --- Линия ---
      doc
        .moveTo(50, doc.y)
        .lineTo(545, doc.y)
        .stroke();
      doc.moveDown(1);

      // --- Задание водителю ---
      doc.fontSize(11).text("ЗАДАНИЕ ВОДИТЕЛЮ:", {underline: true});
      doc.moveDown(0.3);

      doc.text(
        `Маршрут: ${trip.routeDescription || "—"}`
      );
      doc.text(
        `Груз: ${trip.cargoDescription || "—"}`
      );
      doc.moveDown(1);

      // --- Информация о доходе ---
      if (trip.income !== undefined && trip.income !== null) {
        doc
          .moveTo(50, doc.y)
          .lineTo(545, doc.y)
          .stroke();
        doc.moveDown(1);
        doc.text(`Доход за рейс: ${trip.income.toLocaleString("ru-RU")} ₽`);
        doc.moveDown(0.5);
      }

      // --- Подписи ---
      doc.moveDown(2);
      doc.text("____________________________  /Водитель/", {indent: 300});
      doc.moveDown(1);
      doc.text("____________________________  /Владелец/", {indent: 300});

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

function formatTime(date: Date): string {
  const h = date.getHours().toString().padStart(2, "0");
  const m = date.getMinutes().toString().padStart(2, "0");
  return `${h}:${m}`;
}
