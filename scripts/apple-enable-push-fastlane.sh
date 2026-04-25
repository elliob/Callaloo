#!/usr/bin/env bash
#
# Optional: enable Push Notifications on your App ID via Apple's APIs (Spaceship),
# using fastlane's `produce` tool. Requires Ruby + fastlane (`brew install fastlane`).
#
# After this succeeds, open Xcode, clean build folder, and rebuild so provisioning
# profiles pick up the new capability.
#
# Usage:
#   ./scripts/apple-enable-push-fastlane.sh be.Callaloo
#
# You must be authenticated for Spaceship (Apple ID). Typical options:
#   export FASTLANE_USER='you@example.com'
#   # or use App Store Connect API key JSON (see fastlane docs)
#
set -euo pipefail

BUNDLE_ID="${1:-be.Callaloo}"

if ! command -v fastlane >/dev/null 2>&1; then
  echo "fastlane is not installed. Install with: brew install fastlane" >&2
  echo "Or enable Push manually: https://developer.apple.com/account/resources/identifiers/list" >&2
  exit 1
fi

echo "Enabling Push Notifications for App ID: $BUNDLE_ID"
fastlane produce enable_services \
  -a "$BUNDLE_ID" \
  --push-notification

echo "Done. In Xcode: Product → Clean Build Folder, then build again."
