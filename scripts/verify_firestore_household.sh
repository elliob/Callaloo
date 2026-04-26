#!/usr/bin/env bash
# Verify step-3 data for Firestore security rules: users/{uid}, members/{uid}, and
# households/{hid} (primaryAdminUid). Uses Application Default / gcloud user credentials
# (run: gcloud auth login && gcloud auth application-default login if needed).
#
# Usage:
#   export FIREBASE_PROJECT=callaloo-dev   # optional; default from .firebaserc
#   ./scripts/verify_firestore_household.sh <householdId> [expectedAuthUid]
#
# If [expectedAuthUid] is omitted, the script loads primaryAdminUid from the household doc.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${FIREBASE_PROJECT:-}" ]] && [[ -f .firebaserc ]]; then
  # shellcheck disable=SC2002
  FIREBASE_PROJECT="$(grep -E '^\s*"default"\s*:' .firebaserc 2>/dev/null | head -1 | sed -E 's/.*"default"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
fi
PROJECT="${FIREBASE_PROJECT:-}"
if [[ -z "$PROJECT" ]]; then
  echo "Set FIREBASE_PROJECT or add projects.default in .firebaserc" >&2
  exit 1
fi

HIDE="${1:-}"
if [[ -z "$HIDE" ]]; then
  echo "Usage: $0 <householdId> [expectedAuthUid]" >&2
  exit 1
fi
EXPECTED_UID="${2:-}"

if ! command -v gcloud >/dev/null; then
  echo "gcloud is required (Google Cloud SDK)." >&2
  exit 1
fi
if ! command -v python3 >/dev/null; then
  echo "python3 is required." >&2
  exit 1
fi

TOKEN="$(gcloud auth print-access-token)"
BASE="https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:batchGet"

batch_get() {
  local -a names=("$@")
  local json i first=1
  json='{"documents":['
  for n in "${names[@]}"; do
    if [[ $first -eq 0 ]]; then json+=", "; fi
    json+="\"$n\""
    first=0
  done
  json+=']}'
  curl -g -sS -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
    -d "$json" "$BASE"
}

P_HOUSEHOLD="projects/${PROJECT}/databases/(default)/documents/households/${HIDE}"
echo "=== Project: ${PROJECT} ==="
echo "=== Household document: ${P_HOUSEHOLD} ==="
household_json="$(batch_get "$P_HOUSEHOLD")"
echo "$household_json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
m=d[0].get('found',{})
if not m: print('MISSING or not found', d); sys.exit(2)
fields=m.get('fields',{})
pa=(fields.get('primaryAdminUid') or {}).get('stringValue')
dn=(fields.get('displayName') or {}).get('stringValue')
print('displayName:', dn)
print('primaryAdminUid:', pa)
" || exit 2

if [[ -z "$EXPECTED_UID" ]]; then
  EXPECTED_UID="$(echo "$household_json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
f=d[0].get('found',{}).get('fields',{})
print((f.get('primaryAdminUid') or {}).get('stringValue') or '', end='')
")"
  if [[ -z "$EXPECTED_UID" ]]; then
    echo "Could not read primaryAdminUid from household" >&2
    exit 1
  fi
  echo "Using primaryAdminUid from household: ${EXPECTED_UID}"
fi

P_USER="projects/${PROJECT}/databases/(default)/documents/users/${EXPECTED_UID}"
P_MEMBER="projects/${PROJECT}/databases/(default)/documents/households/${HIDE}/members/${EXPECTED_UID}"

echo
echo "=== users/${EXPECTED_UID} ==="
batch_get "$P_USER" | python3 -c "
import json,sys
d=json.load(sys.stdin)[0]
if 'found' not in d: print('NOT FOUND', d.get('error')); sys.exit(1)
f=d['found'].get('fields',{})
h=(f.get('householdId') or {}).get('stringValue')
r=(f.get('role') or {}).get('stringValue')
e=(f.get('email') or {}).get('stringValue')
print('householdId:', repr(h))
print('role:', repr(r))
print('email:', repr(e))
if h != '${HIDE}':
  print('MISMATCH: users.householdId != request household', file=sys.stderr)
  sys.exit(1)
if r != 'admin':
  print('MISMATCH: users.role is not admin', file=sys.stderr)
  sys.exit(1)
"

echo
echo "=== households/${HIDE}/members/${EXPECTED_UID} ==="
batch_get "$P_MEMBER" | python3 -c "
import json,sys
d=json.load(sys.stdin)[0]
if 'found' not in d: print('NOT FOUND (member doc)'); sys.exit(1)
f=d['found'].get('fields',{})
r=(f.get('role') or {}).get('stringValue')
print('role:', repr(r))
if r != 'admin':
  print('MISMATCH: members.role is not admin', file=sys.stderr)
  sys.exit(1)
"

echo
echo "OK: users + members + primaryAdminUid line up for this account and household."
echo "If the app still gets PERMISSION_DENIED, check: same Firebase user on device, same PROJECT in GoogleService-Info, and that firestore.rules are deployed to this project."
