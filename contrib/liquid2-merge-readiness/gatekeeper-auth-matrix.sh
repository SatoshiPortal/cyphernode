#!/usr/bin/env bash

set -euo pipefail

PROJECT="${PROJECT:-cyphernode-liquid2-full}"
STACK_DIR="${STACK_DIR:-/home/cypherdeploy/cyphernode-liquid2-full-20260718}"
BASE_URL="${BASE_URL:-https://127.0.0.1/v0}"
TIMEOUT="${TIMEOUT:-15}"

cd "$STACK_DIR"

compose() {
  docker compose -p "$PROJECT" "$@"
}

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

role_rank() {
  case "$1" in
    stats) printf '0' ;;
    watcher) printf '1' ;;
    spender) printf '2' ;;
    admin) printf '3' ;;
    internal) printf '99' ;;
    *) fail "unknown role: $1" ;;
  esac
}

token_for() {
  local id="$1"
  python3 - "$keys_file" "$id" <<'PY'
import base64
import hashlib
import hmac
import json
import re
import sys
import time

keys_path, wanted_id = sys.argv[1], sys.argv[2]
key = None

line_re = re.compile(r'kapi_id="([0-9]+)";kapi_key="([^"]+)"')
with open(keys_path, "r", encoding="utf-8") as fh:
    for line in fh:
        match = line_re.search(line)
        if match and match.group(1) == wanted_id:
            key = match.group(2)
            break

if key is None:
    raise SystemExit(f"missing key for id {wanted_id}")

def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")

header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
payload = b64url(json.dumps({"id": wanted_id, "exp": int(time.time()) + 3600}, separators=(",", ":")).encode())
signing_input = f"{header}.{payload}".encode()
signature = b64url(hmac.new(key.encode(), signing_input, hashlib.sha256).digest())
print(f"{header}.{payload}.{signature}", end="")
PY
}

http_code_for() {
  local endpoint="$1"
  local token="${2:-}"
  local output_file="$tmpdir/body"

  if [ -n "$token" ]; then
    curl -k -sS --max-time "$TIMEOUT" -o "$output_file" -w '%{http_code}' \
      -H "Authorization: Bearer $token" "$BASE_URL/$endpoint"
  else
    curl -k -sS --max-time "$TIMEOUT" -o "$output_file" -w '%{http_code}' \
      "$BASE_URL/$endpoint"
  fi
}

assert_code() {
  local endpoint="$1"
  local actor="$2"
  local expected="$3"
  local actual="$4"

  case "$expected" in
    authn)
      [ "$actual" = "401" ] || [ "$actual" = "403" ] || fail "$endpoint expected 401/403 for $actor, got $actual"
      ;;
    denied)
      [ "$actual" = "403" ] || fail "$endpoint expected 403 for $actor, got $actual"
      ;;
    allowed)
      [ "$actual" != "401" ] && [ "$actual" != "403" ] || fail "$endpoint expected auth pass for $actor, got $actual"
      ;;
    *)
      fail "unknown expected code class: $expected"
      ;;
  esac
}

need curl
need docker
need python3

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

keys_file="$tmpdir/keys.properties"
api_file="$tmpdir/api.properties"
compose exec -T gatekeeper cat /etc/nginx/conf.d/keys.properties > "$keys_file"
compose exec -T gatekeeper cat /etc/nginx/conf.d/api.properties > "$api_file"
chmod 600 "$keys_file" "$api_file"

invalid_token="invalid.invalid.invalid"

users_file="$tmpdir/users"
python3 - "$keys_file" > "$users_file" <<'PY'
import re
import sys

line_re = re.compile(r'kapi_id="([0-9]+)";kapi_key="[^"]+";kapi_groups="([^"]+)"')
for line in open(sys.argv[1], "r", encoding="utf-8"):
    match = line_re.search(line)
    if not match:
        continue
    api_id = match.group(1)
    groups = set(match.group(2).split(","))
    if "admin" in groups:
        rank = 3
    elif "spender" in groups:
        rank = 2
    elif "watcher" in groups:
        rank = 1
    elif "stats" in groups:
        rank = 0
    else:
        rank = -1
    print(f"{api_id}:{rank}:{','.join(sorted(groups))}")
PY

declare -A tokens
while IFS=':' read -r id rank groups; do
  [ -n "$id" ] || continue
  tokens["$id"]="$(token_for "$id")"
done < "$users_file"

failures=0
tested=0

while IFS='=' read -r action role; do
  case "$action" in
    action_*) ;;
    *) continue ;;
  esac

  case "$role" in
    stats|watcher|spender|admin|internal) ;;
    *) continue ;;
  esac

  endpoint="${action#action_}"
  endpoint="${endpoint%%[[:space:]]*}"
  role="${role%%[[:space:]]*}"

  tested=$((tested + 1))

  if ! code="$(http_code_for "$endpoint" "")"; then
    fail "$endpoint no-token request failed"
  fi
  if ! assert_code "$endpoint" "no-token" authn "$code"; then
    failures=$((failures + 1))
  fi

  if ! code="$(http_code_for "$endpoint" "$invalid_token")"; then
    fail "$endpoint invalid-token request failed"
  fi
  if ! assert_code "$endpoint" "invalid-token" authn "$code"; then
    failures=$((failures + 1))
  fi

  required_rank="$(role_rank "$role")"
  while IFS=':' read -r id actual_rank groups; do
    [ -n "$id" ] || continue
    token="${tokens[$id]}"
    if [ "$role" = "internal" ] || [ "$actual_rank" -lt "$required_rank" ]; then
      expected="denied"
    else
      expected="allowed"
    fi

    if ! code="$(http_code_for "$endpoint" "$token")"; then
      fail "$endpoint user $id request failed"
    fi
    if ! assert_code "$endpoint" "user-$id" "$expected" "$code"; then
      failures=$((failures + 1))
    fi
  done < "$users_file"

  pass "$endpoint requires $role"
done < "$api_file"

[ "$tested" -gt 0 ] || fail "no actions parsed from api.properties"
[ "$failures" -eq 0 ] || fail "$failures auth matrix checks failed"

pass "Gatekeeper auth matrix passed for $tested actions"
