import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {Timestamp} from "firebase-admin/firestore";

const db = admin.firestore();

function randomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars[crypto.randomInt(chars.length)];
  }
  return code;
}

function hashCode(code: string): string {
  return crypto.createHash("sha256").update(code).digest("hex");
}

export const generateInviteCode = functions.https.onCall(
  {enforceAppCheck: true},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Не аутентифицирован");

    const driverName = (request.data.driverName as string) || "Водитель";
    const expiresHours = Math.min((request.data.expiresHours as number) || 48, 168);

    const code = randomCode();
    const now = Timestamp.now();
    const expires = Timestamp.fromDate(new Date(now.toDate().getTime() + expiresHours * 3600000));

    await db.collection("invites").add({
      codeHash: hashCode(code),
      ownerId: uid,
      driverName,
      createdAt: now,
      expiresAt: expires,
      used: false,
      usedBy: null,
    });

    functions.logger.info("Invite generated", {ownerId: uid, expires: `${expiresHours}h`});

    return {
      code,
      expiresHours,
      expiresAt: expires.toDate().toISOString(),
    };
  }
);

export const validateInviteCode = functions.https.onCall(
  {enforceAppCheck: true},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Не аутентифицирован");

    const inputCode = (request.data.code as string || "").toUpperCase().replace(/\s/g, "");
    if (inputCode.length < 6) {
      throw new functions.https.HttpsError("invalid-argument", "Неверный формат кода");
    }

    const hash = hashCode(inputCode);

    const snapshot = await db
      .collection("invites")
      .where("codeHash", "==", hash)
      .where("used", "==", false)
      .limit(1)
      .get();

    if (snapshot.empty) {
      throw new functions.https.HttpsError("not-found", "Код не найден или уже использован");
    }

    const doc = snapshot.docs[0];
    const invite = doc.data()!;

    if (invite.expiresAt.toDate() < new Date()) {
      throw new functions.https.HttpsError("failed-precondition", "Срок действия кода истёк");
    }

    const now = Timestamp.now();
    await doc.ref.update({
      used: true,
      usedBy: uid,
      usedAt: now,
    });

    // Link driver to owner
    await db.collection("drivers").doc(uid).set({
      uid,
      ownerId: invite.ownerId,
      displayName: invite.driverName,
      role: "driver",
      createdAt: now,
    }, {merge: true});

    functions.logger.info("Invite used", {driverId: uid, ownerId: invite.ownerId});

    return {
      success: true,
      ownerId: invite.ownerId,
      driverName: invite.driverName,
    };
  }
);
