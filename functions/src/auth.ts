import * as admin from "firebase-admin";

const db = admin.firestore();

export async function checkIsOwner(uid: string): Promise<boolean> {
  const ownerDoc = await db.collection("owners").doc(uid).get();
  if (!ownerDoc.exists) return false;
  const role = ownerDoc.data()?.role;
  return role === "owner" || role === "superadmin" || role === "admin";
}
