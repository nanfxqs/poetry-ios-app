#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE=${IOS_ENV_FILE:-"$ROOT_DIR/.env.ios-device"}
[[ -f "$ENV_FILE" ]] || { printf 'error: missing %s; run scripts/setup-linux-ios.sh.\n' "$ENV_FILE" >&2; exit 2; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${IOS_MAC_HOST:?IOS_MAC_HOST is required}"
: "${IOS_MAC_PROJECT:?IOS_MAC_PROJECT is required}"
: "${IOS_PROJECT_NAME:=PoetryApp}"
: "${IOS_SCHEME:=PoetryApp}"
: "${IOS_CONFIGURATION:=Debug}"
: "${IOS_BUNDLE_ID:=com.nanfl.PoetryApp}"
: "${IOS_IPA_PATH:=$ROOT_DIR/artifacts/${IOS_PROJECT_NAME}.ipa}"
: "${PYMOBILEDEVICE3_BIN:=pymobiledevice3}"

MODE=${1:-run}
case "$MODE" in
  run|logs|install-only|build-only) ;;
  *) printf 'usage: %s [run|logs|install-only|build-only]\n' "$0" >&2; exit 2 ;;
esac

command -v rsync >/dev/null || { printf 'error: rsync is required.\n' >&2; exit 3; }
command -v ssh >/dev/null || { printf 'error: ssh is required.\n' >&2; exit 3; }
command -v "$PYMOBILEDEVICE3_BIN" >/dev/null || { printf 'error: pymobiledevice3 is required.\n' >&2; exit 3; }

if [[ "$MODE" != install-only ]]; then
  printf '==> Syncing source to %s:%s\n' "$IOS_MAC_HOST" "$IOS_MAC_PROJECT"
  rsync -az \
    --exclude '.git/' --exclude '.env.ios-device' --exclude '.ios-tools/' \
    --exclude 'artifacts/' --exclude 'build/' \
    "$ROOT_DIR/" "$IOS_MAC_HOST:$IOS_MAC_PROJECT/"

  printf '==> Building and signing %s on Mac\n' "$IOS_PROJECT_NAME"
  ssh -t "$IOS_MAC_HOST" \
    "cd '$IOS_MAC_PROJECT' && IOS_PROJECT_NAME='$IOS_PROJECT_NAME' IOS_SCHEME='$IOS_SCHEME' IOS_CONFIGURATION='$IOS_CONFIGURATION' ./scripts/mac-build-ipa.sh"

  mkdir -p "$(dirname "$IOS_IPA_PATH")"
  printf '==> Downloading signed IPA\n'
  rsync -az "$IOS_MAC_HOST:$IOS_MAC_PROJECT/artifacts/${IOS_PROJECT_NAME}.ipa" "$IOS_IPA_PATH"
fi

if [[ "$MODE" == build-only ]]; then
  printf 'Built and downloaded %s\n' "$IOS_IPA_PATH"
  exit 0
fi

[[ -f "$IOS_IPA_PATH" ]] || { printf 'error: IPA not found: %s\n' "$IOS_IPA_PATH" >&2; exit 4; }
printf '==> Installing on USB-connected iPhone\n'
"$PYMOBILEDEVICE3_BIN" apps install "$IOS_IPA_PATH"
[[ "$MODE" == install-only ]] && { printf 'Installed %s\n' "$IOS_BUNDLE_ID"; exit 0; }

printf '==> Launching %s\n' "$IOS_BUNDLE_ID"
"$PYMOBILEDEVICE3_BIN" developer dvt launch "$IOS_BUNDLE_ID"
if [[ "$MODE" == logs ]]; then
  printf '==> Streaming matching device logs; press Ctrl-C to stop\n'
  "$PYMOBILEDEVICE3_BIN" syslog live -m "$IOS_PROJECT_NAME"
fi

