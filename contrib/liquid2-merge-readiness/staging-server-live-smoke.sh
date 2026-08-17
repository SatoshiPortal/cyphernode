#!/usr/bin/env bash

set -euo pipefail

PROJECT="${PROJECT:-cyphernode-liquid2-full}"
STACK_DIR="${STACK_DIR:-/home/cypherdeploy/cyphernode-liquid2-full-20260718}"
TIMEOUT="${TIMEOUT:-20}"

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

proxy_curl() {
  compose exec -T proxy curl -sS --max-time "$TIMEOUT" "$@"
}

proxy_get() {
  proxy_curl "http://127.0.0.1:8888/$1"
}

proxy_post() {
  local endpoint="$1"
  local body="$2"
  proxy_curl -H "Content-Type: application/json" -d "$body" "http://127.0.0.1:8888/$endpoint"
}

assert_json() {
  local name="$1"
  local body="$2"
  local filter="$3"

  printf '%s\n' "$body" | jq -e "$filter" >/dev/null || {
    printf 'response for %s failed assertion %s:\n%s\n' "$name" "$filter" "$body" >&2
    exit 1
  }
  pass "$name"
}

need docker
need jq

ps_json="$(compose ps --format json)"
printf '%s\n' "$ps_json" | jq -se '
  def rows: if length == 1 and (.[0] | type) == "array" then .[0] else . end;
  (rows | map(select(.Service == "proxy" and .State == "running")) | length == 1)
  and (rows | map(select(.Service == "postgres" and .State == "running")) | length == 1)
  and (rows | map(select(.Service == "gatekeeper" and .State == "running")) | length == 1)
' >/dev/null || {
  compose ps
  fail "required services are not running"
}
pass "required compose services are running"

body="$(proxy_get helloworld)"
assert_json "proxy helloworld" "$body" '.hello == "world"'

body="$(proxy_get getblockchaininfo)"
assert_json "Bitcoin getblockchaininfo" "$body" '.chain | type == "string"'

body="$(proxy_get getmempoolinfo)"
assert_json "Bitcoin getmempoolinfo" "$body" 'has("size") or has("loaded")'

body="$(proxy_get getbestblockhash)"
assert_json "Bitcoin getbestblockhash" "$body" '.result | type == "string" and length == 64'

body="$(proxy_get getnewaddress)"
btc_address="$(printf '%s\n' "$body" | jq -er '.address')"
[ -n "$btc_address" ] || fail "Bitcoin getnewaddress returned an empty address"
pass "Bitcoin getnewaddress"

body="$(proxy_get listunspent)"
assert_json "Bitcoin listunspent" "$body" '.utxos | type == "array"'

body="$(proxy_get elements_getblockchaininfo)"
assert_json "Elements getblockchaininfo" "$body" '.chain | type == "string"'

body="$(proxy_get elements_getmempoolinfo)"
assert_json "Elements getmempoolinfo" "$body" 'has("size") or has("loaded")'

body="$(proxy_get elements_getwalletinfo)"
assert_json "Elements getwalletinfo" "$body" 'has("walletname") or (.result | type == "object")'

body="$(proxy_post elements_getnewaddress '{}')"
elements_address="$(printf '%s\n' "$body" | jq -er '.address')"
[ -n "$elements_address" ] || fail "Elements getnewaddress returned an empty address"
pass "Elements getnewaddress"

body="$(proxy_post elements_getaddressinfo "$(jq -nc --arg address "$elements_address" '{address:$address}')")"
assert_json "Elements getaddressinfo for owned generated address" "$body" '.result.ismine == true'

watch_label="liquid2-smoke-$(date +%s)-$$"
watch_body="$(jq -nc --arg address "$elements_address" --arg label "$watch_label" '{address:$address,label:$label}')"
body="$(proxy_post elements_watch "$watch_body")"
watch_id="$(printf '%s\n' "$body" | jq -er '.id')"
assert_json "Elements watch insert" "$body" '.inserted == true and (.id | type == "number")'

body="$(proxy_post elements_unwatch "$(jq -nc --argjson id "$watch_id" '{id:$id}')")"
assert_json "Elements unwatch by id" "$body" '.event == "elements_unwatch" and .id == '"$watch_id"

txid="3333333333333333333333333333333333333333333333333333333333333333"
watchtxid_body="$(jq -nc --arg txid "$txid" --arg cb "http://127.0.0.1:1/liquid2-smoke" '{txid:$txid,confirmedCallbackURL:$cb}')"
body="$(proxy_post elements_watchtxid "$watchtxid_body")"
watchtxid_id="$(printf '%s\n' "$body" | jq -er '.id')"
assert_json "Elements watchtxid insert" "$body" '.inserted == true and (.id | type == "number")'

body="$(proxy_post elements_unwatchtxid "$(jq -nc --argjson id "$watchtxid_id" '{id:$id}')")"
assert_json "Elements unwatchtxid by id" "$body" '.event == "elements_unwatchtxid" and .id == '"$watchtxid_id"

if compose ps --services | grep -qx paymentalist; then
  status_code="$(compose exec -T proxy curl -sS --max-time "$TIMEOUT" -o /dev/null -w '%{http_code}' http://paymentalist:8080/check_bolt11_mrh)"
  [ "$status_code" = "405" ] || [ "$status_code" = "404" ] || fail "Paymentalist route probe returned HTTP $status_code"
  pass "Paymentalist service is reachable from proxy network"
fi

ps_json="$(compose ps --format json)"
printf '%s\n' "$ps_json" | jq -se '
  def rows: if length == 1 and (.[0] | type) == "array" then .[0] else . end;
  rows | all(.[]; (.State == "running") and ((.Health == "") or (.Health == "healthy")))
' >/dev/null || {
  compose ps
  fail "stack is not healthy after smoke tests"
}
pass "stack remains running/healthy after smoke tests"
