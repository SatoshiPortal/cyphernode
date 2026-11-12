#!/bin/sh
#
# Unit test for ark_send, ark_board and ark_watch request handling with
# stubbed barkd, PostgreSQL and broker. Runs anywhere with sh and jq.
#
#   cd proxy_docker/app/script && sh ../tests/test-ark-send.sh

set -u

SQL_LOG=$(mktemp)
BARKD_LOG=$(mktemp)
MQTT_LOG=$(mktemp)
trap 'rm -f "${SQL_LOG}" "${BARKD_LOG}" "${MQTT_LOG}"' EXIT

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

DEST=ark1qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l

# Movements 4 and 5 already paid 500 sats to DEST. Movement 6 appears once
# /wallet/send has been called; NEW_MOVEMENTS adds more look-alikes.
BARKD_MODE=ok
CONNECTED=true
NEW_MOVEMENTS=
barkd_call() {
  rm -f "$(barkd_http_code_file)"
  printf '%s %s\n' "${1}" "${2}" >> "${BARKD_LOG}"
  case "${BARKD_MODE}" in
    ok)
      case "${2}" in
        /wallet/send) echo '{"message":"Payment sent successfully"}'; return 0 ;;
        /wallet/connected) echo "{\"connected\":${CONNECTED}}"; return 0 ;;
        /history*)
          movements='{"id":4,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"'${DEST}'"},"amount_sat":500}]},{"id":5,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"'${DEST}'"},"amount_sat":500}]}'
          grep -q '^POST /wallet/send$' "${BARKD_LOG}" && movements="${movements}"',{"id":6,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"'${DEST}'"},"amount_sat":500}]}'"${NEW_MOVEMENTS}"
          echo "[${movements}]"; return 0 ;;
        /boards/board-amount) echo '{"funding_tx":{"txid":"txid-b"},"vtxos":["v1"]}'; return 0 ;;
      esac ;;
    down) rm -f "$(barkd_http_code_file)"; return 1 ;;
    down_after)
      case "${2}" in
        /history*) echo '[]'; return 0 ;;
        /wallet/connected) echo '{"connected":true}'; return 0 ;;
        *) rm -f "$(barkd_http_code_file)"; return 1 ;;
      esac ;;
    no_history)
      case "${2}" in
        /history*) rm -f "$(barkd_http_code_file)"; return 1 ;;
        /wallet/send) echo '{"message":"Payment sent successfully"}'; return 0 ;;
        /wallet/connected) echo '{"connected":true}'; return 0 ;;
        *) rm -f "$(barkd_http_code_file)"; return 1 ;;
      esac ;;
    refused)
      case "${2}" in
        /wallet/connected) echo '{"connected":true}'; return 0 ;;
        /wallet/send) printf 409 > "$(barkd_http_code_file)"; echo '{"message":"Insufficient money available. Needed 0.00001000 BTC but 0.00000500 BTC is available"}'; return 2 ;;
        *) printf 409 > "$(barkd_http_code_file)"; echo '{"message":"insufficient funds"}'; return 2 ;;
      esac ;;
  esac
}

sql() {
  printf '%s\n' "${1}" >> "${SQL_LOG}"
  case "${1}" in
    "INSERT INTO ark_job (kind, label, callback_url, vtxos, status) VALUES ('board', 'dupjob'"*) ;;
    "INSERT INTO ark_job"*) printf '9' ;;
    "INSERT INTO ark_watching"*) printf '7' ;;
    *) ;;
  esac
}

mosquitto_pub() {
  printf '%s %s\n' "${4}" "${6}" >> "${MQTT_LOG}"
}

# --- ark_send ----------------------------------------------------------------

out=$(ark_send '{"destination":"bc1qnotark","amount":500}')
check "non-Ark destination is refused" "jqcheck '${out}' '.error.code == -5'"

out=$(ark_send '{"destination":"'${DEST}'","amount":"12.5"}')
check "non-integer amount is refused" "jqcheck '${out}' '.error.code == -32602'"

out=$(ark_send '{"destination":"'${DEST}'","amount":0}')
check "zero amount is refused before barkd is called" \
  "jqcheck '${out}' '.error.code == -32602' && ! grep -q 'POST /wallet/send' '${BARKD_LOG}'"

CONNECTED=false
out=$(ark_send '{"destination":"'${DEST}'","amount":500}')
check "server not connected is refused before anything is sent" \
  "jqcheck '${out}' '.error.code == -32003' && ! grep -q 'POST /wallet/send' '${BARKD_LOG}'"
CONNECTED=true

out=$(ark_send '{"destination":"'${DEST}'","amount":500}')
check "successful send is accepted with the movement made after it, not an older one" \
  "jqcheck '${out}' '.status == \"accepted\" and .movementId == 6 and .details.destination == \"${DEST}\" and .details.amount_sat == 500'"
check "send without eventMessage publishes nothing" "! grep -q '^ark_send' '${MQTT_LOG}'"

: > "${BARKD_LOG}"
out=$(ark_send '{"destination":"'${DEST}'","amount":500,"eventMessage":"ZXZlbnQ="}')
check "eventMessage is published with the movement id" \
  "grep -q '^ark_send {\"destination\":\"${DEST}\",\"amount_sat\":500,\"movementId\":6,\"eventMessage\":\"ZXZlbnQ=\"}$' '${MQTT_LOG}'"

: > "${BARKD_LOG}"
NEW_MOVEMENTS=',{"id":7,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"'${DEST}'"},"amount_sat":500}]}'
out=$(ark_send '{"destination":"'${DEST}'","amount":500}')
check "two look-alike movements after the send leave movementId null" \
  "jqcheck '${out}' '.status == \"accepted\" and .movementId == null'"
NEW_MOVEMENTS=

: > "${BARKD_LOG}"
BARKD_MODE=no_history
out=$(ark_send '{"destination":"'${DEST}'","amount":500}')
check "history unavailable still sends and leaves movementId null" \
  "jqcheck '${out}' '.status == \"accepted\" and .movementId == null' && grep -q 'POST /wallet/send' '${BARKD_LOG}'"

: > "${BARKD_LOG}"
BARKD_MODE=down
out=$(ark_send '{"destination":"'${DEST}'","amount":500}')
check "barkd unreachable before the send is refused" \
  "jqcheck '${out}' '.error.code == 1' && ! grep -q 'POST /wallet/send' '${BARKD_LOG}'"

BARKD_MODE=down_after
out=$(ark_send '{"destination":"'${DEST}'","amount":500}')
check "transport failure after the send reports the outcome unknown" "jqcheck '${out}' '.error.code == -32001'"

BARKD_MODE=refused
out=$(ark_send '{"destination":"'${DEST}'","amount":500}')
check "barkd refusal is reported with its status and message" \
  "jqcheck '${out}' '.error.code == 409 and (.error.message | startswith(\"Insufficient money available\"))'"
check "insufficient funds is published like spend does" \
  "grep -q '^insufficientfunds {\"method\":\"ark_send\",\"error\":\"Insufficient money available' '${MQTT_LOG}'"

# --- ark_board ---------------------------------------------------------------

BARKD_MODE=ok
: > "${BARKD_LOG}"
out=$(ark_board '{"amount":1000,"label":"topup-1","callbackURL":"http://app/job?x=1|2"}')
check "board records the job before barkd is called" \
  "jqcheck '${out}' '.id == 9 and .txid == \"txid-b\" and .vtxos == [\"v1\"]' && grep -n 'INSERT INTO ark_job\|UPDATE ark_job SET txid' '${SQL_LOG}' | sort -n | head -1 | grep -q 'INSERT'"
check "board stores the funding txid and vtxos" \
  "grep -q \"UPDATE ark_job SET txid='txid-b', vtxos='\\[\\\"v1\\\"\\]' WHERE id=9\" '${SQL_LOG}'"

out=$(ark_board '{"amount":1000,"label":"dupjob"}')
check "duplicate job label is refused and never reaches barkd" \
  "jqcheck '${out}' '.error.message == \"duplicate label\"' && grep -c 'POST /boards/board-amount' '${BARKD_LOG}' | grep -q '^1$'"

BARKD_MODE=refused
out=$(ark_board '{"amount":1000,"label":"topup-2"}')
check "refused board is marked failed with barkd's message" \
  "jqcheck '${out}' '.error.code == 409' && grep -q \"UPDATE ark_job SET status='failed', error='insufficient funds' WHERE id=9\" '${SQL_LOG}'"
BARKD_MODE=ok

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

out=$(ark_unwatchrequest "1 OR true" "" "")
check "unwatch refuses a non-integer id" \
  "jqcheck '${out}' '.error.code == -32602' && ! grep -q 'WHERE id=1 OR true' '${SQL_LOG}'"

exit ${fail}
