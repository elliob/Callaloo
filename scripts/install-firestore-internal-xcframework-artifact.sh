#!/usr/bin/env bash
# Last-resort fix for: "There is no XCFramework found at …/FirebaseFirestoreInternal.xcframework"
#
# That path is only used when SPM evaluates firebase-ios-sdk *without* FIREBASE_SOURCE_FIRESTORE
# (binary Firestore). Prefer ./scripts/open-xcode-firestore-from-source.sh and
# ./scripts/repair-firestore-spm-cache.sh --reset-spm first.
#
# This script downloads Google's FirebaseFirestoreInternal.zip (same URL/checksum as Firebase
# 12.13.0 Package.swift) and extracts it into DerivedData where SPM expects it.
#
# Usage:
#   ./scripts/install-firestore-internal-xcframework-artifact.sh
#   DERIVED_DATA=/path/to/Callaloo-xxxxx ./scripts/install-firestore-internal-xcframework-artifact.sh
set -euo pipefail

ZIP_URL="https://dl.google.com/firebase/ios/bin/firestore/12.13.0/rc0/FirebaseFirestoreInternal.zip"
EXPECTED_SHA256="ea5326424da7dd8926c8311004ffaccf6a42b59ac0a9c72aba9f203040e6c8b0"

if [[ -n "${DERIVED_DATA:-}" ]]; then
  DD="$DERIVED_DATA"
else
  DD=$(ls -d "${HOME}/Library/Developer/Xcode/DerivedData/Callaloo-"* 2>/dev/null | head -1 || true)
fi

if [[ -z "${DD:-}" ]]; then
  echo "Could not find Callaloo DerivedData. Build once in Xcode or set DERIVED_DATA to your Callaloo-* folder." >&2
  exit 1
fi

DEST="${DD}/SourcePackages/artifacts/firebase-ios-sdk/FirebaseFirestoreInternal"
mkdir -p "$DEST"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Firestore internal binary (Firebase 12.13.0)..."
curl -fL -o "$TMP/FirebaseFirestoreInternal.zip" "$ZIP_URL"

echo "$EXPECTED_SHA256  $TMP/FirebaseFirestoreInternal.zip" | shasum -a 256 -c -

rm -rf "${DEST}/FirebaseFirestoreInternal.xcframework"
unzip -q "$TMP/FirebaseFirestoreInternal.zip" -d "$DEST"

test -d "${DEST}/FirebaseFirestoreInternal.xcframework"
echo "Installed: ${DEST}/FirebaseFirestoreInternal.xcframework"
