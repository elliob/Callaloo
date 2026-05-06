#!/usr/bin/env bash
# Wrapper for `xcodebuild` that sets FIREBASE_SOURCE_FIRESTORE=1 so Swift Package
# Manager evaluates firebase-ios-sdk's Package.swift with Firestore built from
# source (grpc-ios, abseil-cpp-SwiftPM, boringssl-SwiftPM). Without this, SPM
# falls back to prebuilt grpc-binary / abseil-cpp-binary XCFrameworks that lack
# dSYMs Xcode 16+ expects when uploading to App Store Connect.
#
# The project pins Firebase 12.x and commits Package.resolved for the source
# stack; always use this wrapper (or resolve-packages.sh) so the lockfile stays
# consistent.
#
# Usage (examples):
#   ./scripts/xcodebuild-callaloo.sh -scheme Callaloo -destination 'generic/platform=iOS' -configuration Release archive
#   ./scripts/xcodebuild-callaloo.sh -scheme Callaloo -resolvePackageDependencies
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FIREBASE_SOURCE_FIRESTORE=1
if command -v launchctl >/dev/null 2>&1; then
  launchctl setenv FIREBASE_SOURCE_FIRESTORE 1 2>/dev/null || true
fi
exec xcodebuild -project "$ROOT/Callaloo.xcodeproj" "$@"
