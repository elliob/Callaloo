#!/usr/bin/env bash
# Re-resolve Swift packages with Firestore-from-source mode (see xcodebuild-callaloo.sh).
#
# If Package.resolved keeps reverting to grpc-binary / abseil-cpp-binary (can happen
# after resolving without FIREBASE_SOURCE_FIRESTORE), delete the lockfile and resolve
# again:
#   ./scripts/resolve-packages.sh --reset
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FIREBASE_SOURCE_FIRESTORE=1
if [[ "${1:-}" == "--reset" ]]; then
  rm -f "$ROOT/Callaloo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  shift
fi
exec xcodebuild -project "$ROOT/Callaloo.xcodeproj" -scheme Callaloo -resolvePackageDependencies "$@"
