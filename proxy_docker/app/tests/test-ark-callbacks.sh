#!/bin/sh
#
# Unit test for the Ark callback logic. Runs anywhere with sh and jq: barkd,
# PostgreSQL and the notifier are replaced by stubs that record what they
# were asked to do.
#
#   cd proxy_docker/app/script && sh ../tests/test-ark-callbacks.sh

set -u

SQL_LOG=$(mktemp)
NOTIFY_LOG=$(mktemp)
trap 'rm -f "${SQL_LOG}" "${NOTIFY_LOG}"' EXIT

TRACING=
BARKD_URL=stub
BARKD_CURL_CFG=/dev/null
BARKD_TOKEN_FILE=/dev/null
TOR_ADDR_WATCH_WEBHOOKS=
TOR_TXID_WATCH_WEBHOOKS=

. ./ark_callbacks.sh

# --- stubs -------------------------------------------------------------------

# Watch 7 on ark1receiver with a callback; board job 3 waits for vtxo "v-board".
sql() {
  printf '%s\n' "${1}" >> "${SQL_LOG}"
  case "${1}" in
    "SELECT id FROM ark_watching WHERE watching AND address='ark1receiver'") printf '7' ;;
    "SELECT id, vtxos FROM ark_job WHERE status='pending' AND kind='board' AND movement_id IS NULL") printf '3|["v-board"]' ;;
    "SELECT r.id, w.callback_url"*) printf '11|http://app/cb|order-42|ZXZlbnQ=|ark1receiver|12345|9|["v-recv"]|12345' ;;
    "SELECT id, kind, label, callback_url"*) printf '3|board|topup-1|http://app/job|txid-b|9|["v-board"]|successful' ;;
    *) ;;
  esac
}

notify_web() {
  printf '%s %s\n' "${1}" "${2}" >> "${NOTIFY_LOG}"
  echo '{"curl_code":0,"http_code":200}'
  return 0
}

barkd_call() { return 1; }

# --- fixtures ----------------------------------------------------------------

receive='{"id":9,"status":"successful","subsystem":{},"intended_balance_sat":12345,"effective_balance_sat":12345,"offchain_fee_sat":0,
  "sent_to":[],"received_on":[{"destination":{"type":"ark","value":"ark1receiver"},"amount_sat":12345}],
  "input_vtxos":[],"output_vtxos":["v-recv","v-board"],"exited_vtxos":[],"time":{}}'
pending='{"id":10,"status":"pending","sent_to":[],"received_on":[{"destination":{"type":"ark","value":"ark1receiver"},"amount_sat":1}],"output_vtxos":[]}'

fail=0
check() {
  if eval "${2}"; then
    echo "ok   - ${1}"
  else
    echo "FAIL - ${1}"
    fail=1
  fi
}

# --- tests -------------------------------------------------------------------

ark_process_movement "${pending}"
check "pending movements are ignored" "! grep -q 'INSERT INTO ark_receive' '${SQL_LOG}'"

ark_process_movement "${receive}"
check "received movement is recorded once per watch" \
  "grep -c \"INSERT INTO ark_receive (movement_id, ark_watching_id, address, amount_sat, vtxos) VALUES (9, 7, 'ark1receiver', 12345\" '${SQL_LOG}' | grep -q '^1$'"
check "offboard jobs are matched by movement id" \
  "grep -q \"UPDATE ark_job SET status='successful', movement_id=9 WHERE status='pending' AND movement_id=9\" '${SQL_LOG}'"
check "board jobs are matched by their vtxo ids" \
  "grep -q \"UPDATE ark_job SET status='successful', movement_id=9 WHERE id=3\" '${SQL_LOG}'"

ark_do_callbacks
check "receive callback carries address, amount, label, eventMessage and movement id" \
  "grep -q '^http://app/cb {\"id\":11,\"event\":\"ark_receive\",\"address\":\"ark1receiver\",\"label\":\"order-42\",\"eventMessage\":\"ZXZlbnQ=\",\"amount_sat\":12345,\"expectedAmount\":12345,\"movementId\":9,\"vtxos\":\\[\"v-recv\"\\]}$' '${NOTIFY_LOG}'"
check "job callback names the kind, label, txid and movement id" \
  "grep -q '^http://app/job {\"id\":3,\"event\":\"ark_board\",\"label\":\"topup-1\",\"status\":\"successful\",\"txid\":\"txid-b\",\"movementId\":9,\"vtxos\":\\[\"v-board\"\\]}$' '${NOTIFY_LOG}'"
check "delivered callbacks are marked" \
  "grep -q 'UPDATE ark_receive SET calledback=true' '${SQL_LOG}' && grep -q 'UPDATE ark_job SET calledback=true' '${SQL_LOG}'"

exit ${fail}
