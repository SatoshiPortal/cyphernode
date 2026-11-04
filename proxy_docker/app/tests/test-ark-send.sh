#!/bin/sh
#
# Unit test for ark_send and ark_watch request handling with stubbed barkd
# and PostgreSQL. Runs anywhere with sh and jq.
#
#   cd proxy_docker/app/script && sh ../tests/test-ark-send.sh

set -u

SQL_LOG=$(mktemp)
trap 'rm -f "${SQL_LOG}"' EXIT

TRACING=
BARKD_URL=stub
BARKD_CURL_CFG=/dev/null
BARKD_TOKEN_FILE=/dev/null

. ./ark_watchrequest.sh

fail=0
jqcheck() {
  [ "$(printf '%s' "${1}" | jq -r "${2}" 2>/dev/null)" = "true" ]
}
check() {
  if eval "${2}"; then
    echo "ok   - ${1}"
  else
    echo "FAIL - ${1}"
    fail=1
  fi
}

# --- stubs -------------------------------------------------------------------

BARKD_MODE=ok
barkd_call() {
  rm -f "$(barkd_http_code_file)"
  case "${BARKD_MODE}" in
    ok)
      case "${2}" in
        /wallet/send) echo '{"message":"Payment sent"}'; return 0 ;;
        /history*) echo '[{"id":4,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l"},"amount_sat":500}]},{"id":5,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l"},"amount_sat":500}]}]'; return 0 ;;
      esac ;;
    down) rm -f "$(barkd_http_code_file)"; return 1 ;;
    refused) printf 409 > "$(barkd_http_code_file)"; echo '{"message":"insufficient funds"}'; return 2 ;;
  esac
}

sql() {
  printf '%s\n' "${1}" >> "${SQL_LOG}"
  case "${1}" in
    "SELECT id, status, movement_id, destination, amount_sat FROM ark_send WHERE label='dup'") printf '1|successful|4|ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l|500' ;;
    "SELECT id, status, movement_id, destination, amount_sat FROM ark_send WHERE label="*) ;;
    "INSERT INTO ark_send"*) printf '2' ;;
    "INSERT INTO ark_watching"*) printf '7' ;;
    *) ;;
  esac
}

# --- ark_send ----------------------------------------------------------------

out=$(ark_send '{"destination":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l","amount":500,"label":"dup"}')
check "duplicate label is refused with the stored outcome" \
  "jqcheck '${out}' '.error.message == \"duplicate label\" and .movementId == 4 and .status == \"successful\"'"

out=$(ark_send '{"destination":"bc1qnotark","amount":500,"label":"bad"}')
check "non-Ark destination is refused" "jqcheck '${out}' '.error.code == -5'"

out=$(ark_send '{"destination":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l","amount":"12.5","label":"fraction"}')
check "non-integer amount is refused" "jqcheck '${out}' '.error.code == -32602'"

out=$(ark_send '{"destination":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l","amount":500,"label":"order-1"}')
check "successful send reports the latest matching movement" \
  "jqcheck '${out}' '.status == \"successful\" and .movementId == 5 and .label == \"order-1\"'"
check "send is recorded before barkd is called" \
  "grep -q \"INSERT INTO ark_send (label, destination, amount_sat, status) VALUES ('order-1', 'ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l', 500, 'pending')\" '${SQL_LOG}'"
check "successful send is persisted with its movement id" \
  "grep -q \"UPDATE ark_send SET status='successful', movement_id=5 WHERE id=2\" '${SQL_LOG}'"

BARKD_MODE=down
out=$(ark_send '{"destination":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l","amount":500,"label":"order-2"}')
check "transport failure leaves the send in unknown state" \
  "jqcheck '${out}' '.status == \"unknown\"' && grep -q \"UPDATE ark_send SET status='unknown' WHERE id=2\" '${SQL_LOG}'"

BARKD_MODE=refused
out=$(ark_send '{"destination":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l","amount":500,"label":"order-3"}')
check "barkd refusal is recorded as failed with its message" \
  "jqcheck '${out}' '.error.code == 409 and .error.message == \"insufficient funds\"' && grep -q \"UPDATE ark_send SET status='failed', error='insufficient funds' WHERE id=2\" '${SQL_LOG}'"

out=$(ark_send '{"destination":"ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l","amount":500,"label":"it'"'"'s"}')
check "labels with quotes are escaped for SQL" "grep -q \"VALUES ('it''s'\" '${SQL_LOG}'"

# --- ark_watch ---------------------------------------------------------------

out=$(ark_watchrequest '{"address":"tark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l","callbackURL":"http://app/cb","label":"o-1","eventMessage":"ZQ==","expectedAmount":100}')
check "watch is inserted and echoed" \
  "jqcheck '${out}' '.id == 7 and .inserted == true and .expectedAmount == 100 and .eventMessage == \"ZQ==\"'"
check "watch upserts on address and callback" \
  "grep -q \"ON CONFLICT (address, COALESCE(callback_url, '')) DO UPDATE SET watching=true\" '${SQL_LOG}'"

out=$(ark_watchrequest '{"address":"1BitcoinAddress","callbackURL":"http://app/cb"}')
check "watch refuses a non-Ark address" "jqcheck '${out}' '.error.code == -5'"

out=$(ark_unwatchrequest "12" "" "")
check "unwatch by id" "jqcheck '${out}' '.id == 12' && grep -q 'UPDATE ark_watching SET watching=false WHERE id=12' '${SQL_LOG}'"

exit ${fail}
