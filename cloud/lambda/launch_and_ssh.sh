#!/usr/bin/env bash
set -euo pipefail

# One-command Lambda launch + SSH helper.
#
# Required env:
#   LAMBDA_API_KEY  - Lambda Cloud API key
#   SSH_KEY_NAME    - SSH key name already registered in Lambda Cloud
#
# Optional env:
#   REGION_NAME     (default: us-west-1)
#   INSTANCE_TYPE   (default: gpu_1x_h100_pcie)
#   INSTANCE_NAME   (default: dreamdojo-<timestamp>)
#   FILE_SYSTEM_NAME (optional persistent filesystem name)
#   API_BASE        (default: https://cloud.lambdalabs.com/api/v1)
#   POLL_SECONDS    (default: 10)
#   MAX_WAIT_SECONDS (default: 900)
#   SSH_USER        (default: ubuntu)
#   SSH_OPTIONS     (default: -o StrictHostKeyChecking=accept-new)
#   OPEN_SSH        (default: 1) set to 0 to only print SSH command
#   AUTO_BOOTSTRAP  (default: 0) set to 1 to run cloud/lambda/bootstrap_instance.sh remotely after connect
#   REPO_URL        (default: https://github.com/davidlgilmour75-bit/DreamDojo.git)
#   REPO_DIR        (default: $HOME/DreamDojo)

require() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

parse_launch_instance_id() {
  python3 - "$1" <<'PY'
import json, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)

# Common shape: {"data": {"instance_ids": ["id"]}}
obj = data.get("data", data)
ids = []
if isinstance(obj, dict):
    if isinstance(obj.get("instance_ids"), list):
        ids = obj.get("instance_ids", [])
    elif isinstance(obj.get("instances"), list):
        # Some APIs may return full instance objects
        ids = [x.get("id") for x in obj.get("instances", []) if isinstance(x, dict) and x.get("id")]

print(ids[0] if ids else "")
PY
}

parse_instance_status_ip() {
  python3 - "$1" "$2" <<'PY'
import json, sys
raw = sys.argv[1]
target_id = sys.argv[2]

try:
    data = json.loads(raw)
except Exception:
    print("||")
    raise SystemExit(0)

root = data.get("data", data)

candidates = []
if isinstance(root, list):
    candidates = [x for x in root if isinstance(x, dict)]
elif isinstance(root, dict):
    for key in ("instances", "items", "data"):
        if isinstance(root.get(key), list):
            candidates = [x for x in root.get(key, []) if isinstance(x, dict)]
            break

match = None
for inst in candidates:
    if str(inst.get("id", "")) == target_id:
        match = inst
        break

if not match:
    print("||")
    raise SystemExit(0)

status = str(match.get("status", ""))
ip = str(match.get("ip", "") or match.get("public_ip", "") or match.get("publicIp", ""))
name = str(match.get("name", ""))
print(f"{status}|{ip}|{name}")
PY
}

require LAMBDA_API_KEY
require SSH_KEY_NAME

API_BASE="${API_BASE:-https://cloud.lambdalabs.com/api/v1}"
REGION_NAME="${REGION_NAME:-us-west-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-gpu_1x_h100_pcie}"
INSTANCE_NAME="${INSTANCE_NAME:-dreamdojo-$(date +%Y%m%d-%H%M%S)}"
FILE_SYSTEM_NAME="${FILE_SYSTEM_NAME:-}"
POLL_SECONDS="${POLL_SECONDS:-10}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-900}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_OPTIONS="${SSH_OPTIONS:--o StrictHostKeyChecking=accept-new}"
OPEN_SSH="${OPEN_SSH:-1}"
AUTO_BOOTSTRAP="${AUTO_BOOTSTRAP:-0}"
REPO_URL="${REPO_URL:-https://github.com/davidlgilmour75-bit/DreamDojo.git}"
REPO_DIR="${REPO_DIR:-\$HOME/DreamDojo}"

LAUNCH_PAYLOAD="$({
  REGION_NAME="$REGION_NAME" \
  INSTANCE_TYPE="$INSTANCE_TYPE" \
  INSTANCE_NAME="$INSTANCE_NAME" \
  SSH_KEY_NAME="$SSH_KEY_NAME" \
  FILE_SYSTEM_NAME="$FILE_SYSTEM_NAME" \
  python3 - <<'PY'
import json, os
payload = {
    "region_name": os.environ["REGION_NAME"],
    "instance_type_name": os.environ["INSTANCE_TYPE"],
    "ssh_key_names": [os.environ["SSH_KEY_NAME"]],
    "name": os.environ["INSTANCE_NAME"],
}
fs_name = os.environ.get("FILE_SYSTEM_NAME", "").strip()
if fs_name:
    payload["file_system_names"] = [fs_name]
print(json.dumps(payload))
PY
})"

echo "Launching Lambda instance..."
echo "  region:        $REGION_NAME"
echo "  instance_type: $INSTANCE_TYPE"
echo "  name:          $INSTANCE_NAME"
if [ -n "$FILE_SYSTEM_NAME" ]; then
  echo "  filesystem:    $FILE_SYSTEM_NAME"
fi

LAUNCH_RESP="$(curl -sS -u "$LAMBDA_API_KEY:" \
  -X POST "$API_BASE/instance-operations/launch" \
  -H "Content-Type: application/json" \
  -d "$LAUNCH_PAYLOAD")"

INSTANCE_ID="$(parse_launch_instance_id "$LAUNCH_RESP")"
if [ -z "$INSTANCE_ID" ]; then
  echo "Failed to parse instance ID from launch response:" >&2
  echo "$LAUNCH_RESP" >&2
  exit 1
fi

echo "Launch requested. instance_id=$INSTANCE_ID"
echo "$INSTANCE_ID" > .lambda-last-instance-id

elapsed=0
ip=""
status=""
name=""
while [ "$elapsed" -lt "$MAX_WAIT_SECONDS" ]; do
  LIST_RESP="$(curl -sS -u "$LAMBDA_API_KEY:" "$API_BASE/instances")"
  parsed="$(parse_instance_status_ip "$LIST_RESP" "$INSTANCE_ID")"
  status="${parsed%%|*}"
  rest="${parsed#*|}"
  ip="${rest%%|*}"
  name="${rest#*|}"

  if [ -n "$status" ] || [ -n "$ip" ]; then
    echo "  status=${status:-unknown} ip=${ip:-pending}"
  else
    echo "  waiting for instance metadata..."
  fi

  if [ -n "$ip" ] && [ "$ip" != "None" ]; then
    break
  fi

  sleep "$POLL_SECONDS"
  elapsed=$((elapsed + POLL_SECONDS))
done

if [ -z "$ip" ] || [ "$ip" = "None" ]; then
  echo "Timed out waiting for public IP after ${MAX_WAIT_SECONDS}s" >&2
  echo "Instance ID saved to .lambda-last-instance-id" >&2
  exit 1
fi

SSH_CMD="ssh $SSH_OPTIONS ${SSH_USER}@${ip}"

echo
echo "Instance ready"
echo "  id:   $INSTANCE_ID"
echo "  name: ${name:-$INSTANCE_NAME}"
echo "  ip:   $ip"
echo "  ssh:  $SSH_CMD"

auto_bootstrap_cmd=""
if [ "$AUTO_BOOTSTRAP" = "1" ]; then
  auto_bootstrap_cmd="set -euo pipefail; "
  auto_bootstrap_cmd+="if [ -d ${REPO_DIR}/.git ]; then git -C ${REPO_DIR} pull --ff-only; else git clone ${REPO_URL} ${REPO_DIR}; fi; "
  auto_bootstrap_cmd+="cd ${REPO_DIR}; bash cloud/lambda/bootstrap_instance.sh"
fi

if [ "$OPEN_SSH" = "1" ]; then
  if [ -n "$auto_bootstrap_cmd" ]; then
    echo "Running remote bootstrap, then opening SSH session..."
    eval "$SSH_CMD 'bash -lc '"'"'${auto_bootstrap_cmd}'"'"''"
  fi
  echo "Opening SSH session..."
  exec bash -lc "$SSH_CMD"
fi

echo "OPEN_SSH=0 set; not opening shell automatically."
