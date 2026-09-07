#!/usr/bin/env bash
# Run on Linux. Only reads the dedicated Poetry Compose snapshot volume on Mac.
set -euo pipefail
if [[ $# != 2 || ! $1 =~ ^poetry-[a-zA-Z0-9.-]+\.sqlite$ ]]; then
  echo "Usage: $0 poetry-TIMESTAMP-ID.sqlite NEW_LOCAL_DIRECTORY" >&2
  exit 2
fi
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE=${IOS_ENV_FILE:-"$ROOT_DIR/.env.ios-device"}
[[ -f "$ENV_FILE" ]] || { printf 'error: missing %s; run scripts/setup-linux-ios.sh.\n' "$ENV_FILE" >&2; exit 2; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${IOS_MAC_HOST:?IOS_MAC_HOST is required}"
: "${IOS_MAC_PROJECT:?IOS_MAC_PROJECT is required}"
printf -v compose_file '%q' "$IOS_MAC_PROJECT/service/compose.yaml"
snapshot=$1
mkdir -- "$2"
trap 'echo "Export interrupted; partial directory retained for inspection: $2" >&2' ERR
ssh "$IOS_MAC_HOST" "POETRY_TOKEN_FILE=/dev/null /usr/local/bin/docker compose -f $compose_file exec -T snapshots python snapshots.py verify /snapshots/$snapshot" > "$2/remote.json"
ssh "$IOS_MAC_HOST" "POETRY_TOKEN_FILE=/dev/null /usr/local/bin/docker compose -f $compose_file exec -T snapshots cat /snapshots/$snapshot" > "$2/$snapshot"
python3 - "$2" "$snapshot" <<'PY'
import hashlib,json,pathlib,sys
folder=pathlib.Path(sys.argv[1]); path=folder/sys.argv[2]
actual=hashlib.sha256(path.read_bytes()).hexdigest()
expected=json.loads((folder/'remote.json').read_text())['sha256']
if actual != expected:
    raise SystemExit('Export checksum mismatch; do not restore this file')
print('Verified export SHA-256:',actual)
PY
python3 "$(dirname "$0")/../service/snapshots.py" verify "$2/$snapshot"
