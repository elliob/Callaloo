import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2/options";
import * as admin from "firebase-admin";
import { defineString } from "firebase-functions/params";

setGlobalOptions({ region: "us-central1" });

admin.initializeApp();

const resendApiKey = defineString("RESEND_API_KEY", { default: "" });
const emailFrom = defineString("EMAIL_FROM", { default: "Callaloo <onboarding@resend.dev>" });

export const createHousehold = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();
  const existing = await db.collection("users").doc(uid).get();
  if (existing.data()?.householdId) {
    throw new HttpsError("failed-precondition", "This account already belongs to a family.");
  }

  const email = (request.auth.token.email as string | undefined) ?? "";
  const displayName = typeof request.data?.displayName === "string" && request.data.displayName.trim().length > 0
    ? request.data.displayName.trim()
    : "Family";

  const householdRef = db.collection("households").doc();
  const hid = householdRef.id;

  const batch = db.batch();
  batch.set(householdRef, {
    displayName,
    primaryAdminUid: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(householdRef.collection("members").doc(uid), {
    role: "admin",
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    email,
  });
  batch.set(
    db.collection("users").doc(uid),
    {
      householdId: hid,
      role: "admin",
      email,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();
  return { householdId: hid };
});

export const createParentInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const householdId = request.data?.householdId as string | undefined;
  if (!householdId) {
    throw new HttpsError("invalid-argument", "householdId is required.");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();
  const memberSnap = await db.doc(`households/${householdId}/members/${uid}`).get();
  if (!memberSnap.exists || memberSnap.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Only household admins can create invites.");
  }

  const inviteRef = db.collection("invites").doc();
  await inviteRef.set({
    householdId,
    createdByUid: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
    usedAt: null,
  });

  return { inviteId: inviteRef.id };
});

export const redeemParentInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const inviteId = (request.data?.inviteId as string | undefined)?.trim();
  if (!inviteId) {
    throw new HttpsError("invalid-argument", "inviteId is required.");
  }

  const uid = request.auth.uid;
  const email = (request.auth.token.email as string | undefined) ?? "";
  const db = admin.firestore();

  const existingUser = await db.collection("users").doc(uid).get();
  const existingHousehold = existingUser.data()?.householdId as string | undefined;
  if (existingHousehold) {
    throw new HttpsError("failed-precondition", "This account is already linked to a family.");
  }

  const inviteRef = db.collection("invites").doc(inviteId);
  const householdId = await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "That invite code was not found.");
    }

    const invite = inviteSnap.data()!;
    if (invite.usedAt) {
      throw new HttpsError("failed-precondition", "This invite was already used.");
    }

    const expiresAt = invite.expiresAt as admin.firestore.Timestamp;
    if (expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("failed-precondition", "This invite has expired.");
    }

    const hid = invite.householdId as string;
    if (!hid) {
      throw new HttpsError("failed-precondition", "Invite is missing household data.");
    }

    tx.update(inviteRef, { usedAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.set(db.doc(`households/${hid}/members/${uid}`), {
      role: "parent",
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      email,
    });
    tx.set(
      db.collection("users").doc(uid),
      {
        householdId: hid,
        role: "parent",
        email,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return hid;
  });

  return { householdId };
});

export const onOrderRequestCreated = onDocumentCreated(
  "households/{householdId}/orderRequests/{orderId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }

    const householdId = event.params.householdId as string;
    const orderId = event.params.orderId as string;
    const data = snap.data();

    const items = (data.itemsSnapshot as Array<Record<string, unknown>> | undefined) ?? [];
    const lines = items.map((row) => String(row.title ?? "")).filter((t) => t.length > 0);
    const summary = lines.length > 0 ? lines.join(", ") : "(no titles)";

    const db = admin.firestore();
    const adminsSnap = await db
      .collection(`households/${householdId}/members`)
      .where("role", "==", "admin")
      .get();

    const adminUids = adminsSnap.docs.map((d) => d.id);
    const tokens: string[] = [];
    const emails: string[] = [];

    for (const adminUid of adminUids) {
      const userSnap = await db.collection("users").doc(adminUid).get();
      const token = userSnap.data()?.fcmToken as string | undefined;
      if (token) {
        tokens.push(token);
      }
      const em = (userSnap.data()?.email as string | undefined) ?? "";
      if (em.includes("@")) {
        emails.push(em);
      }
    }

    if (tokens.length > 0) {
      const messaging = admin.messaging();
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: "New Callaloo order request",
          body: summary,
        },
        data: {
          householdId,
          orderId,
          type: "order_request",
        },
      });
    }

    const apiKey = resendApiKey.value();
    const uniqueEmails = Array.from(new Set(emails));
    if (apiKey && uniqueEmails.length > 0) {
      const html = `
        <p>A parent submitted a new order request in Callaloo.</p>
        <p><strong>Household</strong>: ${householdId}</p>
        <p><strong>Order</strong>: ${orderId}</p>
        <ul>
          ${lines.map((t) => `<li>${escapeHtml(t)}</li>`).join("")}
        </ul>
      `;

      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: emailFrom.value(),
          to: uniqueEmails,
          subject: "Callaloo: new order request",
          html,
        }),
      });
    }
  }
);

function escapeHtml(input: string): string {
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
