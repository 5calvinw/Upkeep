#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKEND_ENV="$ROOT_DIR/backend/.env"
GLOBAL_ENV="$ROOT_DIR/.env"

read_env_value() {
  local file="$1"
  local key="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  local line
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | tail -n1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi

  local value="${line#*=}"
  value="$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  value="$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  printf '%s' "$value"
}

GOOGLE_WEB_CLIENT_ID=""
SOURCE_ENV=""
if GOOGLE_WEB_CLIENT_ID="$(read_env_value "$BACKEND_ENV" "GOOGLE_WEB_CLIENT_ID")"; then
  SOURCE_ENV="$BACKEND_ENV"
elif GOOGLE_WEB_CLIENT_ID="$(read_env_value "$GLOBAL_ENV" "GOOGLE_WEB_CLIENT_ID")"; then
  SOURCE_ENV="$GLOBAL_ENV"
else
  echo "Error: GOOGLE_WEB_CLIENT_ID not found in:"
  echo "  - $BACKEND_ENV"
  echo "  - $GLOBAL_ENV"
  exit 1
fi

if [[ -z "$GOOGLE_WEB_CLIENT_ID" ]]; then
  echo "Error: GOOGLE_WEB_CLIENT_ID is present but empty in $SOURCE_ENV"
  exit 1
fi

echo "Using GOOGLE_WEB_CLIENT_ID from: $SOURCE_ENV"

cd "$FRONTEND_DIR"
flutter run \
  -d chrome \
  --web-hostname localhost \
  --web-port 3000 \
  --dart-define="GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID" \
  "$@"
