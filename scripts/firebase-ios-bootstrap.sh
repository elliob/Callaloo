#!/usr/bin/env bash
#
# Create (or locate) the Firebase iOS app for Callaloo, download GoogleService-Info.plist,
# and sync Google Sign-In URL scheme into Config/Callaloo-Info.plist.
#
# Prerequisites: Node.js, firebase-tools (`npm i -g firebase-tools`), `firebase login`.
#
# Usage:
#   ./scripts/firebase-ios-bootstrap.sh YOUR_PROJECT_ID
#   CREATE_PROJECT=1 ./scripts/firebase-ios-bootstrap.sh callaloo-prod
#   BUNDLE_ID=com.you.app ./scripts/firebase-ios-bootstrap.sh YOUR_PROJECT_ID
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${1:-${FIREBASE_PROJECT_ID:-}}"
BUNDLE_ID="${BUNDLE_ID:-be.Callaloo}"
DISPLAY_NAME="${DISPLAY_NAME:-Callaloo}"
PLIST_OUT="${PLIST_OUT:-"$ROOT_DIR/Callaloo/GoogleService-Info.plist"}"
INFO_MERGE="${INFO_MERGE:-"$ROOT_DIR/Config/Callaloo-Info.plist"}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 <firebaseProjectId>" >&2
  echo "Or set FIREBASE_PROJECT_ID." >&2
  exit 1
fi

cd "$ROOT_DIR"

if [[ "${CREATE_PROJECT:-0}" == "1" ]]; then
  echo "Creating Firebase/GCP project: $PROJECT_ID"
  firebase projects:create "$PROJECT_ID" --display-name "$DISPLAY_NAME"
fi

echo "Selecting Firebase project: $PROJECT_ID"
firebase use "$PROJECT_ID"

find_ios_app_id() {
  firebase -j apps:list IOS --project "$PROJECT_ID" | BUNDLE_ID="$BUNDLE_ID" python3 -c '
import json, os, sys
bundle = os.environ.get("BUNDLE_ID", "")
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(2)
if isinstance(data, list):
    apps = data
elif data.get("status") not in (None, "success"):
    sys.exit(3)
else:
    apps = data.get("result") or []
for app in apps:
    if app.get("namespace") == bundle or app.get("bundleId") == bundle:
        print(app.get("appId", "") or "")
        sys.exit(0)
if apps:
    print(apps[0].get("appId", "") or "")
    sys.exit(0)
sys.exit(4)
'
}

APP_ID="$(BUNDLE_ID="$BUNDLE_ID" find_ios_app_id || true)"
if [[ -z "$APP_ID" || "$APP_ID" == "None" ]]; then
  echo "No iOS app found for bundle id $BUNDLE_ID. Creating one…"
  firebase apps:create IOS "$DISPLAY_NAME" \
    --bundle-id "$BUNDLE_ID" \
    --project "$PROJECT_ID" \
    --non-interactive
  APP_ID="$(BUNDLE_ID="$BUNDLE_ID" find_ios_app_id)"
fi

if [[ -z "$APP_ID" || "$APP_ID" == "None" ]]; then
  echo "Could not determine iOS App ID. Run: firebase -j apps:list IOS --project $PROJECT_ID" >&2
  exit 1
fi

echo "Using iOS App ID: $APP_ID"
mkdir -p "$(dirname "$PLIST_OUT")"
firebase apps:sdkconfig IOS "$APP_ID" --project "$PROJECT_ID" -o "$PLIST_OUT"

if [[ ! -f "$PLIST_OUT" ]]; then
  echo "Failed to write $PLIST_OUT" >&2
  exit 1
fi

REVERSED="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$PLIST_OUT" 2>/dev/null || true)"
if [[ -n "$REVERSED" ]]; then
  echo "Updating URL scheme in $INFO_MERGE -> $REVERSED"
  /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $REVERSED" "$INFO_MERGE" 2>/dev/null \
    || echo "Note: Could not auto-patch $INFO_MERGE (edit CFBundleURLSchemes manually to: $REVERSED)" >&2
else
  echo "Note: REVERSED_CLIENT_ID missing from $PLIST_OUT; update Config/Callaloo-Info.plist manually." >&2
fi

echo ""
echo "Done."
echo "- Wrote: $PLIST_OUT"
echo "- Patched URL scheme (if possible): $INFO_MERGE"
echo ""
echo "APNs (Apple) still requires the Developer website for the .p8 key; Firebase has no fully supported end-to-end CLI for uploading it:"
echo "  1) https://developer.apple.com/account/resources/authkeys/list  → Keys → +  → Apple Push Notifications service (APNs)"
echo "  2) Download the .p8 once, note Key ID + Team ID"
echo "  3) Firebase console → Project settings → Cloud Messaging → Apple app configuration → Upload APNs Auth Key"
echo ""
echo "Optional: open Firebase console for this project:"
echo "  firebase open"
