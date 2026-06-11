import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const checkWaybill = functions.https.onRequest(
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "https://numino.ru");
    res.set("Access-Control-Allow-Methods", "GET");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    const tripId = (req.query.id as string) || "";

    if (!tripId || tripId.length < 8) {
      res.status(400).json({ error: "Не указан идентификатор путевого листа" });
      return;
    }

    try {
      // Ищем по waybillUuid или по прямому ID рейса
      let tripDoc = await db.collection("trips").doc(tripId).get();

      if (!tripDoc.exists) {
        const uuidQuery = await db
          .collection("trips")
          .where("waybillUuid", "==", tripId)
          .limit(1)
          .get();

        if (!uuidQuery.empty) {
          tripDoc = uuidQuery.docs[0];
        }
      }

      if (!tripDoc.exists) {
        res.status(404).json({
          found: false,
          error: "Путевой лист не найден",
        });
        return;
      }

      const trip = tripDoc.data()!;

      const vehicleDoc = await db
        .collection("vehicles")
        .doc(trip.vehicleId)
        .get();
      const vehicle = vehicleDoc.exists ? vehicleDoc.data() : null;

      const driverDoc = await db
        .collection("drivers")
        .doc(trip.driverId)
        .get();
      const driver = driverDoc.exists ? driverDoc.data() : null;

      const startTime = trip.startTime?.toDate?.() || trip.startTime;
      const endTime = trip.endTime?.toDate?.() || trip.endTime;

      res.status(200).json({
        found: true,
        tripId: trip.id.substring(0, 8),
        status: trip.status,
        date: startTime ? new Date(startTime).toLocaleDateString("ru-RU") : null,
        plate: vehicle?.plateNumber || null,
        mileage: trip.mileage || 0,
        route: trip.routeDescription || null,
        verifiedAt: new Date().toISOString(),
      });
    } catch (err) {
      functions.logger.error("checkWaybill error", err);
      res.status(500).json({ error: "Ошибка сервера при проверке" });
    }
  }
);
