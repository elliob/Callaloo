#!/usr/bin/env bash
# Quit Xcode before running this: an open Xcode window often auto-resolves SPM without
# FIREBASE_SOURCE_FIRESTORE and overwrites Package.resolved back to grpc-binary (broken).
#
# Re-resolve Swift packages with Firestore-from-source mode (see xcodebuild-callaloo.sh).
#
# If Package.resolved keeps reverting to grpc-binary / abseil-cpp-binary (can happen
# after resolving without FIREBASE_SOURCE_FIRESTORE), delete the lockfile and resolve
# again:
#   ./scripts/resolve-packages.sh --reset
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FIREBASE_SOURCE_FIRESTORE=1
if command -v launchctl >/dev/null 2>&1; then
  launchctl setenv FIREBASE_SOURCE_FIRESTORE 1 2>/dev/null || true
fi
if [[ "${1:-}" == "--reset" ]]; then
  rm -f "$ROOT/Callaloo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  shift
fi
exec xcodebuild -project "$ROOT/Callaloo.xcodeproj" -scheme Callaloo -resolvePackageDependencies "$@"
