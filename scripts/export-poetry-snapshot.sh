#!/usr/bin/env bash
# Run on Linux. Only reads the dedicated Poetry Compose snapshot volume on Mac.
set -euo pipefail
if [[ $# != 2 || ! $1 =~ ^poetry-[a-zA-Z0-9.-]+\.sqlite$ ]]; then
  echo "Usage: $0 poetry-TIMESTAMP-ID.sqlite NEW_LOCAL_DIRECTORY" >&2
  exit 2
fi
snapshot=$1
mkdir -- "$2"
trap 'echo "Export interrupted; partial directory retained for inspection: $2" >&2' ERR
ssh macmini "POETRY_TOKEN_FILE=/dev/null /usr/local/bin/docker compose -f /Users/nanfm/Projects/poetry-ios-app/service/compose.yaml exec -T snapshots python snapshots.py verify /snapshots/$snapshot" > "$2/remote.json"
ssh macmini "POETRY_TOKEN_FILE=/dev/null /usr/local/bin/docker compose -f /Users/nanfm/Projects/poetry-ios-app/service/compose.yaml exec -T snapshots cat /snapshots/$snapshot" > "$2/$snapshot"
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
