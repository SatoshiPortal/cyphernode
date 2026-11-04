#!/bin/sh
#
# Unit test for the Ark callback and catch-up logic. Runs anywhere with sh,
# jq and flock: barkd, PostgreSQL and the notifier are replaced by stubs that
# record what they were asked to do.
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

. ./ark_manage_missed.sh

# --- stubs -------------------------------------------------------------------

# Watch 7 on ark1receiver with a callback; board job 3 waits for vtxo "v-board".
# Labels and callback URLs contain the psql field separator on purpose.
sql() {
  printf '%s\n' "${1}" >> "${SQL_LOG}"
  case "${1}" in
    "SELECT id FROM ark_watching WHERE watching AND address='ark1receiver'") printf '7' ;;
    "SELECT id, vtxos FROM ark_job WHERE status='pending' AND kind='board' AND movement_id IS NULL") printf '3|["v-board"]' ;;
    "SELECT row_to_json(t) FROM (SELECT r.id, w.callback_url"*)
      printf '{"id":11,"callback_url":"http://app/cb?a=1|2","label":"order|42","event_message":"ZXZlbnQ=","address":"ark1receiver","amount_sat":12345,"movement_id":9,"vtxos":"[\\"v-recv\\"]","expected_amount_sat":12345}' ;;
    "SELECT row_to_json(t) FROM (SELECT id, kind, label, callback_url"*)
      printf '{"id":3,"kind":"board","label":"topup-1","callback_url":"http://app/job","txid":"txid-b","movement_id":9,"vtxos":"[\\"v-board\\"]","status":"successful"}' ;;
    "SELECT value FROM cyphernode_props WHERE property='ark_history_floor'") printf '4' ;;
    "SELECT count(*) FROM ark_send WHERE status='unknown'"*) printf '2' ;;
    "SELECT row_to_json(t) FROM (SELECT id, destination, amount_sat, movement_floor, status FROM ark_send"*)
      printf '{"id":20,"destination":"ark1payee","amount_sat":500,"movement_floor":5,"status":"unknown"}\n{"id":21,"destination":"ark1payee","amount_sat":500,"movement_floor":8,"status":"pending"}' ;;
    *) ;;
  esac
}

notify_web() {
  printf '%s %s\n' "${1}" "${2}" >> "${NOTIFY_LOG}"
  echo '{"curl_code":0,"http_code":200}'
  return 0
}

# Movements 5 and 8 both paid 500 sats to ark1payee; 6 is still pending.
barkd_call() {
  printf '%s %s\n' "${1}" "${2}" >> "${SQL_LOG}"
  case "${2}" in
    /history*)
      echo '[{"id":4,"status":"successful","sent_to":[],"received_on":[],"output_vtxos":[]},
             {"id":5,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"ark1payee"},"amount_sat":500}],"received_on":[],"output_vtxos":[]},
             {"id":6,"status":"pending","sent_to":[],"received_on":[],"output_vtxos":[]},
             {"id":8,"status":"successful","sent_to":[{"destination":{"type":"ark","value":"ark1payee"},"amount_sat":500}],"received_on":[],"output_vtxos":[]}]'
      return 0 ;;
    *) return 1 ;;
  esac
}

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

# --- movements ---------------------------------------------------------------

ark_process_movement "${pending}"
check "pending movements are ignored" "! grep -q 'INSERT INTO ark_receive' '${SQL_LOG}'"

ark_process_movement "${receive}"
check "received movement is recorded once per watch" \
  "grep -c \"INSERT INTO ark_receive (movement_id, ark_watching_id, address, amount_sat, vtxos) VALUES (9, 7, 'ark1receiver', 12345\" '${SQL_LOG}' | grep -q '^1$'"
check "offboard jobs are matched by movement id" \
  "grep -q \"UPDATE ark_job SET status='successful', movement_id=9 WHERE status='pending' AND movement_id=9\" '${SQL_LOG}'"
check "board jobs are matched by their vtxo ids" \
  "grep -q \"UPDATE ark_job SET status='successful', movement_id=9 WHERE id=3\" '${SQL_LOG}'"

# --- callbacks ---------------------------------------------------------------

ark_do_callbacks
check "receive callback keeps labels and URLs containing the field separator" \
  "grep -q '^http://app/cb?a=1|2 {\"id\":11,\"event\":\"ark_receive\",\"address\":\"ark1receiver\",\"label\":\"order|42\",\"eventMessage\":\"ZXZlbnQ=\",\"amount_sat\":12345,\"expectedAmount\":12345,\"movementId\":9,\"vtxos\":\\[\"v-recv\"\\]}$' '${NOTIFY_LOG}'"
check "job callback names the kind, label, txid and movement id" \
  "grep -q '^http://app/job {\"id\":3,\"event\":\"ark_board\",\"label\":\"topup-1\",\"status\":\"successful\",\"txid\":\"txid-b\",\"movementId\":9,\"vtxos\":\\[\"v-board\"\\],\"error\":null}$' '${NOTIFY_LOG}'"
check "delivered callbacks are marked" \
  "grep -q 'UPDATE ark_receive SET calledback=true' '${SQL_LOG}' && grep -q 'UPDATE ark_job SET calledback=true' '${SQL_LOG}'"

# --- catch-up ----------------------------------------------------------------

: > "${SQL_LOG}"
ark_manage_missed
check "catch-up stops below the oldest pending movement" \
  "grep -q \"UPDATE cyphernode_props SET value='5' WHERE property='ark_history_floor'\" '${SQL_LOG}'"
check "unknown send matches only a movement made after it" \
  "grep -q \"UPDATE ark_send SET movement_id=8 WHERE id=20\" '${SQL_LOG}' && grep -q \"UPDATE ark_send SET status='successful' WHERE id=20 AND status='unknown'\" '${SQL_LOG}'"
check "catch-up asks barkd to finish interrupted sends before reading history" \
  "grep -n 'POST /wallet/sync\\|GET /history\$' '${SQL_LOG}' | head -1 | grep -q 'POST /wallet/sync'"
check "stale pending send with no later movement becomes unknown" \
  "grep -q \"UPDATE ark_send SET status='unknown' WHERE id=21 AND status='pending'\" '${SQL_LOG}'"

exit ${fail}
