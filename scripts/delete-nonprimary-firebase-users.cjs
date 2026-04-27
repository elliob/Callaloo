/**
 * Deletes every Firebase Auth user except KEEP_EMAIL and removes matching
 * Firestore users/{uid} and households/{hid}/members/{uid} when present.
 *
 * Requires Admin credentials, e.g.:
 *   gcloud auth application-default login
 * with a Google account that has Owner/Editor on the Firebase/GCP project.
 *
 * Usage:
 *   node scripts/delete-nonprimary-firebase-users.cjs
 *   KEEP_EMAIL=other@example.com node scripts/delete-nonprimary-firebase-users.cjs
 */

const path = require("path");
const admin = require(path.join(__dirname, "../functions/node_modules/firebase-admin"));

const PROJECT_ID = "callaloo-dev";
const KEEP_EMAIL = (process.env.KEEP_EMAIL || "baelliott06@gmail.com").trim().toLowerCase();

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }

  const auth = admin.auth();
  const db = admin.firestore();

  const toDelete = [];
  const toKeep = [];
  let pageToken;

  do {
    const res = await auth.listUsers(1000, pageToken);
    for (const u of res.users) {
      const email = (u.email || "").toLowerCase();
      if (email === KEEP_EMAIL) {
        toKeep.push({ uid: u.uid, email: u.email || "(no email)" });
      } else {
        toDelete.push({ uid: u.uid, email: u.email || "(no email)", providers: u.providerData.map((p) => p.providerId) });
      }
    }
    pageToken = res.pageToken;
  } while (pageToken);

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Keeping: ${KEEP_EMAIL}`);
  console.log(`Keep list (${toKeep.length}):`, JSON.stringify(toKeep, null, 2));
  console.log(`Delete list (${toDelete.length}):`, JSON.stringify(toDelete, null, 2));

  if (toKeep.length === 0) {
    console.error("ERROR: No user matches KEEP_EMAIL. Aborting so we do not delete everyone.");
    process.exit(1);
  }

  for (const { uid, email } of toDelete) {
    console.log(`\nRemoving ${email} (${uid}) …`);
    try {
      const udoc = await db.collection("users").doc(uid).get();
      const householdId = udoc.data()?.householdId;
      if (householdId) {
        await db.doc(`households/${householdId}/members/${uid}`).delete();
        console.log(`  deleted households/${householdId}/members/${uid}`);
      }
      if (udoc.exists) {
        await udoc.ref.delete();
        console.log(`  deleted users/${uid}`);
      }
    } catch (e) {
      console.warn(`  Firestore cleanup warning: ${e.message}`);
    }
    await auth.deleteUser(uid);
    console.log(`  deleted Auth user ${uid}`);
  }

  console.log(`\nDone. Deleted ${toDelete.length} auth user(s).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
