#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE=${IOS_ENV_FILE:-"$ROOT_DIR/.env.ios-device"}
[[ -f "$ENV_FILE" ]] || { printf 'error: missing %s\n' "$ENV_FILE" >&2; exit 2; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
: "${IOS_MAC_HOST:?IOS_MAC_HOST is required}"

if ! ssh -O check "$IOS_MAC_HOST" >/dev/null 2>&1; then
  printf '==> Starting persistent SSH connection to %s\n' "$IOS_MAC_HOST"
  ssh -MNf "$IOS_MAC_HOST"
fi
printf '==> Unlocking the Mac signing keychain (password is not stored)\n'
ssh -t "$IOS_MAC_HOST" \
  'security unlock-keychain "$HOME/Library/Keychains/login.keychain-db" && security find-identity -v -p codesigning'
printf 'Signing session is ready and will be reused according to SSH ControlPersist.\n'

