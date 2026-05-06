#!/usr/bin/env bash
# Clears SPM state that makes Xcode look for FirebaseFirestoreInternal.xcframework when
# Package.resolved is configured for Firestore-from-source (grpc-ios). Run with Xcode quit.
#
# Usage:
#   ./scripts/repair-firestore-spm-cache.sh
#   ./scripts/repair-firestore-spm-cache.sh --reset-spm   # delete entire SourcePackages under DerivedData (slow but thorough)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVED="$ROOT/Callaloo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

if [[ ! -f "$RESOLVED" ]]; then
  echo "Missing Package.resolved at $RESOLVED" >&2
  exit 1
fi

if ! grep -q '"identity" : "grpc-ios"' "$RESOLVED"; then
  echo "Package.resolved does not list grpc-ios (Firestore-from-source). Fix or restore from git before running this." >&2
  exit 1
fi

RESET_SPM=false
if [[ "${1:-}" == "--reset-spm" ]]; then
  RESET_SPM=true
fi

DD=$(ls -d "${HOME}/Library/Developer/Xcode/DerivedData/Callaloo-"* 2>/dev/null | head -1 || true)
if [[ -z "${DD:-}" ]]; then
  echo "No Callaloo DerivedData folder found (nothing to clean)."
else
  echo "Cleaning SPM state under: $DD"
  if [[ "$RESET_SPM" == true ]]; then
    rm -rf "${DD}/SourcePackages"
  else
    rm -rf "${DD}/SourcePackages/artifacts/firebase-ios-sdk/FirebaseFirestoreInternal"
    rm -rf "${DD}/SourcePackages/workspace-state.json"
    rm -rf "${DD}/SourcePackages/checkouts/grpc-binary" \
           "${DD}/SourcePackages/checkouts/abseil-cpp-binary" 2>/dev/null || true
  fi
fi

echo "Re-resolving packages with FIREBASE_SOURCE_FIRESTORE=1..."
export FIREBASE_SOURCE_FIRESTORE=1
if command -v launchctl >/dev/null 2>&1; then
  launchctl setenv FIREBASE_SOURCE_FIRESTORE 1 2>/dev/null || true
fi
exec xcodebuild -project "$ROOT/Callaloo.xcodeproj" -scheme Callaloo -resolvePackageDependencies
