#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_NAME=${IOS_PROJECT_NAME:-PoetryApp}
SCHEME=${IOS_SCHEME:-PoetryApp}
CONFIGURATION=${IOS_CONFIGURATION:-Debug}
DERIVED_DATA="$ROOT_DIR/build/SignedDerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.app"
OUTPUT_DIR="$ROOT_DIR/artifacts"
IPA_PATH="$OUTPUT_DIR/${PROJECT_NAME}.ipa"

[[ $(uname -s) == Darwin ]] || { printf 'error: this script must run on macOS.\n' >&2; exit 2; }
[[ -d "$ROOT_DIR/${PROJECT_NAME}.xcodeproj" ]] || {
  printf 'error: Xcode project not found: %s\n' "$ROOT_DIR/${PROJECT_NAME}.xcodeproj" >&2
  exit 2
}

if ! security find-identity -v -p codesigning 2>/dev/null | grep -Eq '[1-9][0-9]* valid identities found'; then
  if [[ -t 0 ]]; then
    printf 'Mac login keychain is locked. Enter the Mac login password.\n'
    security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
  else
    printf 'error: no usable signing identity; run mac-signing-session.sh first.\n' >&2
    exit 3
  fi
fi

mkdir -p "$OUTPUT_DIR"
xcodebuild \
  -project "$ROOT_DIR/${PROJECT_NAME}.xcodeproj" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build

[[ -d "$APP_PATH" ]] || { printf 'error: signed app not found: %s\n' "$APP_PATH" >&2; exit 4; }
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/poetryapp-ipa.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
mkdir -p "$STAGING_DIR/Payload"
ditto "$APP_PATH" "$STAGING_DIR/Payload/${PROJECT_NAME}.app"
ditto -c -k --sequesterRsrc --keepParent "$STAGING_DIR/Payload" "$IPA_PATH"
printf 'IPA_READY=%s\n' "$IPA_PATH"

