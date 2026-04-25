# Callaloo

Simple iOS app for a **household admin** (you) to maintain a grocery list and receive **push + email** when **parents** tap **Order**. You mark requests **ordered** after checking out manually elsewhere.

## Prerequisites

- Xcode 16+ (project targets iOS 26.x as configured)
- A [Firebase](https://console.firebase.google.com/) project with **Authentication** (Email/Password + Google), **Firestore**, **Cloud Functions**, **Cloud Messaging**, and **Apple** push capability on the iOS app

## CLI: Firebase app, plist, Xcode push, and APNs

| Step | Can you do it from CLI? | What this repo provides |
| --- | --- | --- |
| Create/link Firebase project | **Yes** — `firebase projects:create …` (optional) + `firebase use …` | [`scripts/firebase-ios-bootstrap.sh`](scripts/firebase-ios-bootstrap.sh) |
| Register iOS app + download `GoogleService-Info.plist` | **Yes** — `firebase apps:create IOS … --bundle-id …` + `firebase apps:sdkconfig IOS <appId> -o …` | Same bootstrap script |
| Sync Google Sign-In URL scheme | **Yes** — read `REVERSED_CLIENT_ID` from the plist and patch `Config/Callaloo-Info.plist` | Same bootstrap script |
| Xcode **Push** entitlements (`aps-environment`) | **Partially** — Xcode has no single “official” CLI to toggle the Signing UI, but the project can ship entitlements files and `CODE_SIGN_ENTITLEMENTS` (this repo does). | [`Callaloo/CallalooDebug.entitlements`](Callaloo/CallalooDebug.entitlements), [`Callaloo/CallalooRelease.entitlements`](Callaloo/CallalooRelease.entitlements) |
| Apple **App ID** capability “Push Notifications” | **Not with Xcode alone** — your provisioning profile must include Push. **Optional** third-party CLI: `fastlane produce enable_services`. Otherwise use [Identifiers](https://developer.apple.com/account/resources/identifiers/list) in the Developer portal. | [`scripts/apple-enable-push-fastlane.sh`](scripts/apple-enable-push-fastlane.sh) (optional) |
| Create **APNs Auth Key** (.p8) | **No supported first-party Apple CLI** for creating that key; use the Developer portal (Keys → APNs). | — |
| Upload APNs key to **Firebase** for FCM | **No stable, fully supported Firebase CLI** for the Cloud Messaging “upload APNs key” UI as of common tooling; use Firebase **Console** → Project settings → **Cloud Messaging** → Apple app configuration. | — |

### One-shot Firebase iOS bootstrap (CLI)

From the repo root (after `npm i -g firebase-tools` and `firebase login`):

```bash
./scripts/firebase-ios-bootstrap.sh YOUR_FIREBASE_PROJECT_ID
# Optional: create a new GCP/Firebase project first
CREATE_PROJECT=1 ./scripts/firebase-ios-bootstrap.sh your-new-project-id
# Optional: non-default bundle id (must match Xcode)
BUNDLE_ID=com.example.callaloo ./scripts/firebase-ios-bootstrap.sh YOUR_FIREBASE_PROJECT_ID
```

This writes `Callaloo/GoogleService-Info.plist` and tries to patch `Config/Callaloo-Info.plist` with the correct `REVERSED_CLIENT_ID`.

### Push capability + first successful build

The Xcode target references Push entitlements (`CODE_SIGN_ENTITLEMENTS`). Until the **App ID** has Push enabled, automatic signing may fail with errors about the provisioning profile missing Push / `aps-environment`.

1. **Portal (manual):** [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → your App ID (`be.Callaloo` by default) → enable **Push Notifications** → Save. Then Xcode: **Product → Clean Build Folder** and build again.
2. **fastlane (optional CLI):** install [fastlane](https://docs.fastlane.tools/), export `FASTLANE_USER` (or use an API key per fastlane docs), then run `./scripts/apple-enable-push-fastlane.sh be.Callaloo`.

### APNs key for Firebase (still mostly manual)

1. [Keys](https://developer.apple.com/account/resources/authkeys/list) → **+** → enable **Apple Push Notifications service (APNs)** → download the `.p8` (once), note **Key ID** and **Team ID**.
2. Firebase console → **Project settings** → **Cloud Messaging** → your iOS app → **APNs Authentication Key** → upload.

## iOS setup (manual alternative)

1. In Firebase console, add an **iOS app** with bundle id `be.Callaloo` (or change the bundle id in Xcode and keep Firebase in sync)—or use [`scripts/firebase-ios-bootstrap.sh`](scripts/firebase-ios-bootstrap.sh) above.
2. Ensure `Callaloo/GoogleService-Info.plist` is the real file from Firebase (bootstrap script writes it).
3. Ensure `Config/Callaloo-Info.plist` URL scheme matches **REVERSED_CLIENT_ID** (bootstrap script patches it).
4. Enable **Push** on the Apple App ID (portal or fastlane script), then build in Xcode so provisioning profiles include Push (`Config/Callaloo-Info.plist` already lists `remote-notification`).
5. In Firebase → **Project settings → Cloud Messaging**, upload your **APNs** key so FCM can deliver pushes to your admin device.

## Backend setup

```bash
npm install -g firebase-tools   # if you don’t already have it
cd functions && npm install && npm run build
cd ..
firebase login
firebase use --add   # select your Firebase project; updates .firebaserc
firebase deploy --only firestore:rules,functions
```

### Callable functions & triggers

- `createHousehold`, `createParentInvite`, `redeemParentInvite`
- `onOrderRequestCreated` — sends **FCM** to household admins and (optionally) **Resend** email

### Email (optional)

Functions read **`RESEND_API_KEY`** and **`EMAIL_FROM`** via Firebase [parameterized configuration](https://firebase.google.com/docs/functions/config-env) (`defineString` in `functions/src/index.ts`). Typical options:

- Pass at deploy time (example): `firebase deploy --only functions --params 'RESEND_API_KEY=re_xxx,EMAIL_FROM=Callaloo <verified@yourdomain.com>'`
- Or switch the code to `defineSecret("RESEND_API_KEY")` and store the key in **Secret Manager** (recommended for production).

If `RESEND_API_KEY` is unset, **push still works**; transactional email is skipped.

## Household flow

1. **Admin** signs in → **Create family** → builds list under **List** tab → **Family** tab generates an **invite code**.
2. **Parent** signs in → **I’m a parent** → pastes invite → sees list → **Order**.
3. **Admin** gets push/email → shops manually → **Orders** tab → **Mark as ordered**.
4. Parent device schedules a **local reminder** ~30 days after an order is marked ordered (when the app observes the status change).

## Repo layout

- `Callaloo/` — SwiftUI app
- `functions/` — Firebase Cloud Functions (TypeScript)
- `firestore.rules` — tenant isolation + roles
- `firebase.json` — Firebase CLI wiring
