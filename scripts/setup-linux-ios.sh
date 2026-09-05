#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env.ios-device"

ask() {
  local prompt=$1 default=$2 reply
  printf '%s [%s]: ' "$prompt" "$default" >&2
  read -r reply
  printf '%s' "${reply:-$default}"
}

printf '\nLinux → Mac → iPhone setup\n\n'
IOS_MAC_HOST=$(ask 'Mac SSH host' 'macmini')
IOS_MAC_PROJECT=$(ask 'Absolute project path on Mac' '/Users/nanfm/Projects/poetry-ios-app')
IOS_PROJECT_NAME=$(ask 'Xcode project name' 'PoetryApp')
IOS_SCHEME=$(ask 'Xcode scheme' 'PoetryApp')
IOS_BUNDLE_ID=$(ask 'Bundle ID' 'com.nanfl.PoetryApp')
IOS_CONFIGURATION=$(ask 'Build configuration' 'Debug')

[[ "$IOS_MAC_HOST" =~ ^[A-Za-z0-9_.@:-]+$ ]] || { printf 'error: invalid SSH host.\n' >&2; exit 1; }
[[ "$IOS_MAC_PROJECT" == /* ]] || { printf 'error: Mac path must be absolute.\n' >&2; exit 1; }
[[ "$IOS_PROJECT_NAME" =~ ^[A-Za-z0-9_.-]+$ ]] || { printf 'error: invalid project name.\n' >&2; exit 1; }
[[ "$IOS_SCHEME" =~ ^[A-Za-z0-9_.-]+$ ]] || { printf 'error: invalid scheme.\n' >&2; exit 1; }
[[ "$IOS_BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] || { printf 'error: invalid bundle ID.\n' >&2; exit 1; }

if command -v pymobiledevice3 >/dev/null 2>&1; then
  PYMOBILEDEVICE3_BIN=$(command -v pymobiledevice3)
elif command -v uv >/dev/null 2>&1; then
  printf 'pymobiledevice3 is missing. Install it with uv now? [y/N] '
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 1
  uv tool install --upgrade pymobiledevice3
  PYMOBILEDEVICE3_BIN=$(command -v pymobiledevice3)
else
  printf 'error: install uv and pymobiledevice3 first.\n' >&2
  exit 1
fi

{
  printf 'IOS_MAC_HOST=%s\n' "$IOS_MAC_HOST"
  printf 'IOS_MAC_PROJECT=%s\n' "$IOS_MAC_PROJECT"
  printf 'IOS_PROJECT_NAME=%s\n' "$IOS_PROJECT_NAME"
  printf 'IOS_SCHEME=%s\n' "$IOS_SCHEME"
  printf 'IOS_CONFIGURATION=%s\n' "$IOS_CONFIGURATION"
  printf 'IOS_BUNDLE_ID=%s\n' "$IOS_BUNDLE_ID"
  printf 'IOS_IPA_PATH=%s/artifacts/%s.ipa\n' "$ROOT_DIR" "$IOS_PROJECT_NAME"
  printf 'PYMOBILEDEVICE3_BIN=%s\n' "$PYMOBILEDEVICE3_BIN"
} > "$ENV_FILE"

printf '\nConfiguration written to %s\n' "$ENV_FILE"
printf 'Connect and unlock the iPhone, then verify with:\n  %s usbmux list\n' "$PYMOBILEDEVICE3_BIN"
printf 'Start signing with:\n  ./scripts/mac-signing-session.sh\n'

