#!/usr/bin/env bash
# Prefer this over double-clicking the .xcodeproj: Xcode launched from Finder has
# no FIREBASE_SOURCE_FIRESTORE in its environment, which can re-resolve packages
# back to grpc-binary (breaking App Store dSYM upload fixes).
#
# Open Xcode with FIREBASE_SOURCE_FIRESTORE=1 so Swift Package Manager builds
# Firestore and its native dependencies from source instead of Google's prebuilt
# XCFrameworks (absl / gRPC / BoringSSL / Firestore internal). Those binaries
# ship without dSYMs in a layout Xcode 16+ accepts, which triggers
# "Upload Symbols Failed" for embedded frameworks such as:
#   absl, grpc, grpcpp, openssl_grpc, FirebaseFirestoreInternal
#
# Building from source lets the compiler emit matching dSYM bundles in the archive.
#
# Trade-off: first clean archive is much slower (large C++ compile).
#
# After Xcode launches:
#   1. File > Packages > Reset Package Caches
#   2. File > Packages > Resolve Package Versions
#   3. Product > Clean Build Folder
#   4. Product > Archive
#
# Command-line archives (CI): use the wrapper so SPM always sees the variable:
#   ./scripts/xcodebuild-callaloo.sh -scheme Callaloo -destination 'generic/platform=iOS' archive
#
# Quit Xcode before running this script so the new environment is picked up.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec open --env FIREBASE_SOURCE_FIRESTORE=1 "$ROOT/Callaloo.xcodeproj"
