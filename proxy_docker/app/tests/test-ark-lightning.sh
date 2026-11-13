#!/bin/sh
#
# Unit test for ark_lnpay, ark_lncreateinvoice and the Lightning movement and
# callback handling with stubbed barkd, CLN, PostgreSQL, broker and notifier.
# Runs anywhere with sh, jq and flock.
#
#   cd proxy_docker/app/script && sh ../tests/test-ark-lightning.sh
#
# ARK_LNPAY_WAIT and ARK_LNPAY_POLL shorten ark_lnpay's 85 second wait and
# 2 second poll interval.

set -u

SQL_LOG=$(mktemp)
BARKD_LOG=$(mktemp)
MQTT_LOG=$(mktemp)
NOTIFY_LOG=$(mktemp)
CLN_LOG=$(mktemp)
STATE=$(mktemp -d)
trap 'rm -rf "${SQL_LOG}" "${BARKD_LOG}" "${MQTT_LOG}" "${NOTIFY_LOG}" "${CLN_LOG}" "${STATE}"' EXIT

TRACING=
BARKD_URL=stub
BARKD_CURL_CFG=/dev/null
BARKD_TOKEN_FILE=/dev/null
TOR_ADDR_WATCH_WEBHOOKS=
TOR_TXID_WATCH_WEBHOOKS=
FEATURE_LIGHTNING=false
ARK_LNPAY_WAIT=0
ARK_LNPAY_POLL=0

. ./ark_manage_missed.sh

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
reset() {
  : > "${SQL_LOG}"; : > "${BARKD_LOG}"; : > "${MQTT_LOG}"; : > "${NOTIFY_LOG}"; : > "${CLN_LOG}"
  rm -rf "${STATE}"/*
}

# --- fixtures ----------------------------------------------------------------

# 1000 sat invoice; NOAMOUNT has no amount in its human-readable part.
INV=lntbs10u1p4wu9mgsp5sttz4ch4g63vsxqexnk6wdstdshtzcq7ejsp5lvuh0pr6rktwvlqpp5fz435ku0s38g33eyxhkrgq0kvh6jggfpzr22ht63gw24glaee4sqdqjwd5xzur9yp3ksetrdvxqy9gcqcqzgq9qyysgqa9h8w68vprnrv7edfw57y94taa4zp75sxd995syfpetzmna7zkh826270vmkkpcar8a3e5zna57v239nh7fs5g6j7ngzqx6km69lhtgp8cpvee
NOAMOUNT=lntbs1pzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce6mua7l
HASH=48ab1a5b8f844e88c72435ec3401f665f524212110d4abaf514395547fb9cd60
PRE=6ef6b49d343f350e85ee67520ab71af93a87a7a98c9ad6080e0b8e14600a0556

send_movement() {
  printf '{"id":14,"status":"%s","subsystem":{"name":"bark.lightning_send","kind":"send"},"metadata":{"payment_hash":"%s","payment_preimage":%s,"htlc_vtxos":[]},"sent_to":[{"destination":{"type":"invoice","value":"%s"},"amount_sat":1000}],"received_on":[],"offchain_fee_sat":77,"effective_balance_sat":-1077,"input_vtxos":[],"output_vtxos":[],"exited_vtxos":[],"time":{}}' \
    "${1}" "${HASH}" "$([ "${1}" = "successful" ] && printf '"%s"' "${PRE}" || printf null)" "${INV}"
}
receive_movement='{"id":15,"status":"successful","subsystem":{"name":"bark.lightning_receive","kind":"receive"},"metadata":{"payment_hash":"'${HASH}'","payment_preimage":"'${PRE}'","htlc_vtxos":["v-htlc"]},"sent_to":[],"received_on":[{"destination":{"type":"invoice","value":"'${INV}'"},"amount_sat":30000}],"offchain_fee_sat":160,"effective_balance_sat":29840,"input_vtxos":[],"output_vtxos":["v-recv"],"exited_vtxos":[],"time":{}}'

# --- stubs -------------------------------------------------------------------

# The send movement shows up once /lightning/pay was called, with
# MOVEMENT_STATUS; PREPAID puts a successful one there from the start. The
# send state is PAID_AFTER polls of /lightning/sends away from paid.
BARKD_MODE=ok
MOVEMENT_STATUS=successful
PREPAID=
PAID_AFTER=1
barkd_call() {
  rm -f "$(barkd_http_code_file)"
  case "${2}" in
    /lightning/pay) [ -n "${PAY_SLEEP:-}" ] && sleep "${PAY_SLEEP}" ;;
    /history*) [ -n "${HISTORY_SLEEP:-}" ] && ! grep -q '^POST /lightning/pay' "${BARKD_LOG}" && sleep "${HISTORY_SLEEP}" ;;
  esac
  printf '%s %s %s\n' "${1}" "${2}" "${3:-}" >> "${BARKD_LOG}"
  case "${BARKD_MODE}" in
    ok)
      case "${2}" in
        /wallet/connected) echo '{"connected":true}'; return 0 ;;
        /lightning/pay)
          grep -q "INSERT INTO ark_ln_send .*'${HASH}'" "${SQL_LOG}" && printf 'ROW_BEFORE_POST\n' >> "${BARKD_LOG}"
          echo "{\"message\":\"Payment initiated successfully\",\"payment_hash\":\"${HASH}\"}"; return 0 ;;
        /lightning/sends/*)
          if [ -n "${PREPAID}" ] || [ "$(grep -c '^GET /lightning/sends/' "${BARKD_LOG}")" -ge "${PAID_AFTER}" ] && [ "${MOVEMENT_STATUS}" = "successful" ]; then
            echo "{\"payment_hash\":\"${HASH}\",\"state\":\"paid\",\"invoice\":null,\"preimage\":\"${PRE}\"}"
          else
            echo "{\"payment_hash\":\"${HASH}\",\"state\":\"payment-initiated\",\"invoice\":\"${INV}\",\"preimage\":null}"
          fi
          return 0 ;;
        /history*)
          if [ -n "${PREPAID}" ]; then
            echo "[$(send_movement successful)]"
          elif grep -q '^POST /lightning/pay' "${BARKD_LOG}"; then
            echo "[$(send_movement "${MOVEMENT_STATUS}")]"
          else
            echo '[]'
          fi
          return 0 ;;
        /lightning/receives/invoice) echo "{\"invoice\":\"${INV}\"}"; return 0 ;;
        /lightning/receives/*) echo "{\"payment_hash\":\"${HASH}\",\"state\":\"awaiting-payment\",\"invoice\":\"${INV}\",\"amount_sat\":30000,\"htlc_vtxo_ids\":[]}"; return 0 ;;
      esac ;;
    down_after)
      case "${2}" in
        /wallet/connected) echo '{"connected":true}'; return 0 ;;
        /history*) echo '[]'; return 0 ;;
        *) rm -f "$(barkd_http_code_file)"; return 1 ;;
      esac ;;
    refused)
      case "${2}" in
        /wallet/connected) echo '{"connected":true}'; return 0 ;;
        /history*) echo '[]'; return 0 ;;
        /lightning/pay) printf 409 > "$(barkd_http_code_file)"; echo '{"message":"Insufficient money available. Needed 0.00001077 BTC but 0.00000500 BTC is available"}'; return 2 ;;
        *) printf 409 > "$(barkd_http_code_file)"; echo '{"message":"refused"}'; return 2 ;;
      esac ;;
  esac
}

# Invoice row 5 (label order-123) and send rows are kept as marker files so a
# second pass sees what the first one wrote.
sql() {
  printf '%s\n' "${1}" >> "${SQL_LOG}"
  case "${1}" in
    "INSERT INTO ark_ln_send "*) [ -n "${SQL_FAIL_SEND:-}" ] && return 1 ;;
  esac
  case "${1}" in
    "INSERT INTO ark_ln_invoice (label, amount_sat, description, callback_url, event_message, status) VALUES ('dup'"*) ;;
    "INSERT INTO ark_ln_invoice"*) printf '5' ;;
    "UPDATE ark_ln_send SET status="*" RETURNING COALESCE(event_message, '')")
      if [ ! -f "${STATE}/published" ]; then
        touch "${STATE}/published"
        printf '%s' "${SEND_EVENT:-}"
      fi ;;
    "SELECT payment_hash FROM ark_ln_send WHERE destination="*) printf '%s' "${HASH}" ;;
    "SELECT row_to_json(t) FROM (SELECT id, label, bolt11, payment_hash, callback_url, event_message, amount_sat, received_sat, fee_sat, movement_id FROM ark_ln_invoice WHERE NOT calledback"*)
      [ -f "${STATE}/calledback" ] || printf '{"id":5,"label":"order|123","bolt11":"%s","payment_hash":"%s","callback_url":"http://app/cb?a=1|2","event_message":"ZXZlbnQ=","amount_sat":30000,"received_sat":29840,"fee_sat":160,"movement_id":15}' "${INV}" "${HASH}" ;;
    "UPDATE ark_ln_invoice SET calledback=true, calledback_ts=CURRENT_TIMESTAMP WHERE id=5") touch "${STATE}/calledback" ;;
    "SELECT row_to_json(t) FROM (SELECT id, label, bolt11, payment_hash, amount_sat, description, expires_at, callback_url, event_message, status, movement_id, received_sat, fee_sat, calledback FROM ark_ln_invoice WHERE label='order-123'"*)
      printf '{"id":5,"label":"order-123","bolt11":"%s","payment_hash":"%s","amount_sat":30000,"description":"Bull order #123","expires_at":1762470000,"callback_url":"http://app/cb","event_message":"ZXZlbnQ=","status":"paid","movement_id":15,"received_sat":29840,"fee_sat":160,"calledback":true}' "${INV}" "${HASH}" ;;
    *) ;;
  esac
}

mosquitto_pub() {
  printf '%s %s\n' "${4}" "${6}" >> "${MQTT_LOG}"
}

NOTIFY_FAIL=
notify_web() {
  printf '%s %s\n' "${1}" "${2}" >> "${NOTIFY_LOG}"
  if [ -n "${NOTIFY_FAIL}" ]; then
    echo '{"curl_code":7,"http_code":0}'
    return 7
  fi
  echo '{"curl_code":0,"http_code":200}'
  return 0
}

# Cyphernode's CLN, used only when FEATURE_LIGHTNING is true.
CLN_AMOUNT=1000000
ln_call_lightningd() {
  printf '%s\n' "$*" >> "${CLN_LOG}"
  echo "{\"type\":\"bolt11 invoice\",\"valid\":true,\"currency\":\"tbs\",\"created_at\":1762400000,\"expiry\":900,\"payment_hash\":\"${HASH}\",\"amount_msat\":${CLN_AMOUNT},\"description\":\"order #1\"}"
}

# --- bolt11 amounts ----------------------------------------------------------

check "amount of a 10u invoice is 1000000 msat" "[ \"\$(ark_bolt11_amount_msat ${INV})\" = 1000000 ]"
check "amount-less invoice has no amount" "[ -z \"\$(ark_bolt11_amount_msat ${NOAMOUNT})\" ]"
check "m, n and p multipliers and whole bitcoins" \
  "[ \"\$(ark_bolt11_amount_msat lnbc20m1qqqq)\" = 2000000000 ] && [ \"\$(ark_bolt11_amount_msat lnbcrt2500n1qqqq)\" = 250000 ] && [ \"\$(ark_bolt11_amount_msat lntb100p1qqqq)\" = 10 ] && [ \"\$(ark_bolt11_amount_msat LNBC11QQQQ)\" = 100000000000 ]"
check "offers, lightning addresses and lnurls are not invoices" \
  "! ark_is_bolt11 lno1qqqq && ! ark_is_bolt11 user@domain.com && ! ark_is_bolt11 lnurl1qqqq && ark_is_bolt11 ${INV}"
check "Ark marker detection accepts only one-hop Ark SCIDs" \
  "ark_bolt11_has_hint '{\"routes\":[[{\"short_channel_id\":\"6386283x65536x0\"}]]}' && ark_bolt11_has_hint '{\"routes\":[[{\"short_channel_id\":\"6386283x131072x0\"}]]}' && ! ark_bolt11_has_hint '{\"routes\":[[{\"short_channel_id\":\"6386283x196608x0\"}]]}' && ! ark_bolt11_has_hint '{\"routes\":[[{\"short_channel_id\":\"6386283x65536x0\"},{\"short_channel_id\":\"1x1x1\"}]]}'"

( barkd_call() { [ "${BARKD_TIMEOUT:-}" = 5 ] && echo '{"server_pubkey":"02aa"}'; }
  check "Ark server lookup has a five-second timeout" "[ \"\$(ark_server_pubkey)\" = 02aa ]"
) || fail=1

( . ./paymentalist.sh
  send_to_paymentalist() { printf '%s' "${2}"; }
  payload=$(check_bolt11_mrh 'lnbc1"escaped' '' '02aa')
  check "paymentalist request safely JSON-escapes the invoice" \
    "[ \"\$(printf '%s' '${payload}' | jq -r '.invoice')\" = 'lnbc1\"escaped' ]"
) || fail=1

# --- ark_lnpay ---------------------------------------------------------------

out=$(ark_lnpay '{"expected_msatoshi":"1000000"}')
check "pay without destination is refused" "jqcheck '${out}' '.error.code == -32602'"

out=$(ark_lnpay '{"destination":"'${INV}'","expected_msatoshi":"2000000"}')
check "amount mismatch is refused from the invoice itself, before barkd is called" \
  "jqcheck '${out}' '.error.code == -32602 and .error.data.invoice_msatoshi == 1000000' && ! grep -q 'POST /lightning/pay' '${BARKD_LOG}'"

out=$(ark_lnpay '{"destination":"'${NOAMOUNT}'"}')
check "amount-less invoice without expected_msatoshi is refused" "jqcheck '${out}' '.error.code == -32602'"

out=$(ark_lnpay '{"destination":"user@domain.com"}')
check "lightning address without expected_msatoshi is refused" "jqcheck '${out}' '.error.code == -32602'"

out=$(ark_lnpay '{"destination":"'${NOAMOUNT}'","expected_msatoshi":"1500"}')
check "expected_msatoshi that is not whole satoshis is refused" "jqcheck '${out}' '.error.code == -32602'"

reset
SEND_EVENT=ZXZlbnQ=
PAID_AFTER=3
ARK_LNPAY_WAIT=5
out=$(ark_lnpay '{"bolt11":"'${INV}'","expected_msatoshi":"1000000","eventMessage":"ZXZlbnQ="}')
rc=$?
check "paid invoice is complete with the preimage, amounts and movement from history" \
  "[ ${rc} -eq 0 ] && jqcheck '${out}' '.status == \"complete\" and .payment_hash == \"${HASH}\" and .payment_preimage == \"${PRE}\" and .amount_msat == 1000000 and .amount_sent_msat == 1077000 and .movementId == 14 and .destination == \"${INV}\" and (.already_paid == null)'"
check "the invoice amount is not sent to barkd" "grep -q '^POST /lightning/pay {\"destination\":\"${INV}\"}$' '${BARKD_LOG}'"
check "the send state was polled until paid" "[ \"\$(grep -c '^GET /lightning/sends/${HASH}' '${BARKD_LOG}')\" -eq 3 ]"
check "without local CLN decode, barkd's returned hash keys the event row" \
  "grep -q \"INSERT INTO ark_ln_send (payment_hash, destination, event_message, status) VALUES ('${HASH}', '${INV}', 'ZXZlbnQ=', 'pending')\" '${SQL_LOG}'"
check "the outcome is recorded and published once" \
  "grep -q \"UPDATE ark_ln_send SET status='complete', movement_id=14, published=true WHERE payment_hash='${HASH}' AND NOT published\" '${SQL_LOG}' && [ \"\$(grep -c '^ark_lnpay ' '${MQTT_LOG}')\" -eq 1 ] && grep -q '^ark_lnpay {\"payment_hash\":\"${HASH}\",\"movementId\":14,\"status\":\"complete\",\"eventMessage\":\"ZXZlbnQ=\"}$' '${MQTT_LOG}'"
ARK_LNPAY_WAIT=0
PAID_AFTER=1

reset
MOVEMENT_STATUS=pending
out=$(ark_lnpay '{"destination":"'${INV}'"}')
rc=$?
check "unresolved at the deadline is pending with the movement so far, nothing published" \
  "[ ${rc} -eq 0 ] && jqcheck '${out}' '.status == \"pending\" and .payment_hash == \"${HASH}\" and .payment_preimage == null and .amount_msat == 1000000 and .movementId == 14' && ! grep -q '^ark_lnpay' '${MQTT_LOG}' && ! grep -q 'published=true' '${SQL_LOG}'"

reset
MOVEMENT_STATUS=failed
out=$(ark_lnpay '{"destination":"'${INV}'","eventMessage":"ZXZlbnQ="}')
rc=$?
check "failed movement makes the payment failed and publishes it" \
  "[ ${rc} -eq 1 ] && jqcheck '${out}' '.status == \"failed\" and .movementId == 14' && grep -q '^ark_lnpay {\"payment_hash\":\"${HASH}\",\"movementId\":14,\"status\":\"failed\",\"eventMessage\":\"ZXZlbnQ=\"}$' '${MQTT_LOG}'"
MOVEMENT_STATUS=successful

reset
out=$(ark_lnpay '{"destination":"'${NOAMOUNT}'","expected_msatoshi":"40000000"}')
check "amount-less invoice is paid for expected_msatoshi" \
  "jqcheck '${out}' '.status == \"complete\"' && grep -q '^POST /lightning/pay {\"destination\":\"${NOAMOUNT}\",\"amount_sat\":40000}$' '${BARKD_LOG}'"

reset
upper_invoice=$(printf '%s' "${INV}" | tr 'a-z' 'A-Z')
out=$(ark_lnpay "{\"destination\":\"${upper_invoice}\"}")
check "uppercase BOLT11 is normalized before barkd and history lookup" \
  "jqcheck '${out}' '.status == \"complete\" and .destination == \"${INV}\"' && grep -q '^POST /lightning/pay {\"destination\":\"${INV}\"}$' '${BARKD_LOG}'"

reset
out=$(ark_lnpay '{"destination":"user@domain.com","expected_msatoshi":"40000000"}')
check "lightning address is paid for expected_msatoshi and looked up by hash in the full history" \
  "jqcheck '${out}' '.status == \"complete\" and .destination == \"user@domain.com\"' && grep -q '^POST /lightning/pay {\"destination\":\"user@domain.com\",\"amount_sat\":40000}$' '${BARKD_LOG}' && ! grep -q '^GET /history?' '${BARKD_LOG}' && grep -q '^GET /history ' '${BARKD_LOG}'"

reset
PREPAID=1
out=$(ark_lnpay '{"destination":"'${INV}'","expected_msatoshi":"1000000"}')
rc=$?
check "already paid invoice is reported, not paid again" \
  "[ ${rc} -eq 0 ] && jqcheck '${out}' '.already_paid == true and .status == \"complete\" and .payment_hash == \"${HASH}\" and .movementId == 14' && ! grep -q 'POST /lightning/pay' '${BARKD_LOG}'"
PREPAID=

reset
FEATURE_LIGHTNING=true HISTORY_SLEEP=0.3 PAY_SLEEP=0.3
ark_lnpay "{\"destination\":\"${INV}\"}" > "${STATE}/first" &
first_pid=$!
ark_lnpay "{\"destination\":\"${INV}\"}" > "${STATE}/second" &
second_pid=$!
wait "${first_pid}"; wait "${second_pid}"
check "simultaneous payments of one invoice submit only once" \
  "[ \"\$(grep -c '^POST /lightning/pay' '${BARKD_LOG}')\" -eq 1 ]"
FEATURE_LIGHTNING=false HISTORY_SLEEP= PAY_SLEEP=

reset
BARKD_MODE=down_after
out=$(ark_lnpay '{"destination":"'${INV}'"}')
check "transport failure after the request reports the outcome unknown" "jqcheck '${out}' '.error.code == -32001'"

reset
BARKD_MODE=refused
out=$(ark_lnpay '{"destination":"'${INV}'"}')
check "insufficient funds is refused with barkd's message and published" \
  "jqcheck '${out}' '.error.code == 409 and (.error.message | startswith(\"Insufficient money available\"))' && grep -q '^insufficientfunds {\"method\":\"ark_lnpay\",\"error\":\"Insufficient money available' '${MQTT_LOG}'"
BARKD_MODE=ok

# With Cyphernode's CLN: description check and payment hash before the call.
reset
FEATURE_LIGHTNING=true
out=$(ark_lnpay '{"destination":"'${INV}'","expected_description":"order #2"}')
check "description mismatch is refused with the CLN decode" \
  "jqcheck '${out}' '.error.code == -32602' && grep -q \"^decode ${INV}\" '${CLN_LOG}' && ! grep -q 'POST /lightning/pay' '${BARKD_LOG}'"

reset
SQL_FAIL_SEND=1
out=$(ark_lnpay '{"destination":"'${INV}'","eventMessage":"ZXZlbnQ="}')
rc=$?
check "failed pre-submission SQL insert prevents the Ark payment" \
  "[ ${rc} -eq 1 ] && jqcheck '${out}' '.error.code == -32002 and (.error.message | contains(\"nothing was sent\"))' && grep -q '^INSERT INTO ark_ln_send ' '${SQL_LOG}' && ! grep -q '^POST /lightning/pay' '${BARKD_LOG}'"
SQL_FAIL_SEND=

reset
FEATURE_LIGHTNING=false SQL_FAIL_SEND=1
out=$(ark_lnpay '{"destination":"'${INV}'","eventMessage":"ZXZlbnQ="}')
rc=$?
check "failed post-submission SQL insert reports an unknown outcome" \
  "[ ${rc} -eq 1 ] && jqcheck '${out}' '.error.code == -32001 and (.error.message | contains(\"outcome unknown\"))' && grep -q '^POST /lightning/pay' '${BARKD_LOG}'"
SQL_FAIL_SEND= FEATURE_LIGHTNING=true

reset
out=$(ark_lnpay '{"destination":"'${INV}'","expected_msatoshi":"1000000","expected_description":"order #1"}')
check "matching amount and description pay and look the invoice up by its hash" \
  "jqcheck '${out}' '.status == \"complete\" and .payment_hash == \"${HASH}\"' && grep -q 'POST /lightning/pay' '${BARKD_LOG}' && grep -q '^ROW_BEFORE_POST$' '${BARKD_LOG}'"
FEATURE_LIGHTNING=false

# --- ark_lncreateinvoice -----------------------------------------------------

reset
out=$(ark_lncreateinvoice '{"msatoshi":"30000000","label":"order-123","description":"Bull order #123","expiry":"900","callbackUrl":"http://app/cb","eventMessage":"ZXZlbnQ="}')
check "invoice is created and echoed with its payment hash from barkd" \
  "jqcheck '${out}' '.id == 5 and .label == \"order-123\" and .bolt11 == \"${INV}\" and .payment_hash == \"${HASH}\" and .msatoshi == 30000000 and .amount_msat == 30000000 and .status == \"unpaid\" and .callbackUrl == \"http://app/cb\" and (.expires_at > 1762400000)'"
check "the label is recorded before barkd is called" \
  "grep -n 'INSERT INTO ark_ln_invoice\|POST /lightning/receives/invoice' '${SQL_LOG}' '${BARKD_LOG}' | head -1 | grep -q 'INSERT'"
check "barkd gets the amount in satoshis, the description and the expiry" \
  "grep -q '^POST /lightning/receives/invoice {\"amount_sat\":30000,\"description\":\"Bull order #123\",\"expiry_secs\":900}$' '${BARKD_LOG}'"
check "the invoice and payment hash are stored" \
  "grep -q \"UPDATE ark_ln_invoice SET bolt11='${INV}', payment_hash='${HASH}', expires_at=[0-9]* WHERE id=5\" '${SQL_LOG}'"

out=$(ark_lncreateinvoice '{"msatoshi":"30000000","label":"dup"}')
check "duplicate label is refused and never reaches barkd" \
  "jqcheck '${out}' '.error.message == \"duplicate label\"' && [ \"\$(grep -c 'POST /lightning/receives/invoice' '${BARKD_LOG}')\" -eq 1 ]"

out=$(ark_lncreateinvoice '{"msatoshi":"30000500","label":"order-124"}')
check "msatoshi that is not whole satoshis is refused" "jqcheck '${out}' '.error.code == -32602'"

out=$(ark_lncreateinvoice '{"label":"order-125"}')
check "msatoshi is required" "jqcheck '${out}' '.error.code == -32602'"

reset
BARKD_MODE=refused
out=$(ark_lncreateinvoice '{"msatoshi":"30000000","label":"order-126"}')
check "refused invoice frees its label" \
  "jqcheck '${out}' '.error.code == 409' && grep -q 'DELETE FROM ark_ln_invoice WHERE id=5' '${SQL_LOG}'"
BARKD_MODE=ok

reset
FEATURE_LIGHTNING=true
out=$(ark_lncreateinvoice '{"msatoshi":"30000000","label":"order-127"}')
check "with CLN the expiry comes from the decoded invoice" \
  "jqcheck '${out}' '.expires_at == 1762400900 and .payment_hash == \"${HASH}\"' && ! grep -q \"GET /lightning/receives/${INV}\" '${BARKD_LOG}'"
FEATURE_LIGHTNING=false

out=$(ark_lngetinvoice order-123)
check "invoice lookup returns the row and barkd's receive state" \
  "jqcheck '${out}' '.status == \"paid\" and .movementId == 15 and .amount_received_msat == 29840000 and .fee_sat == 160 and .receive_state == \"awaiting-payment\" and .msatoshi == 30000000'"

out=$(ark_lngetinvoice nolabel)
check "unknown invoice label" "jqcheck '${out}' '.error.code == -32602'"

# --- movements and callbacks -------------------------------------------------

reset
ark_process_movement "${receive_movement}"
check "lightning receive marks the invoice paid with the net amount and fee" \
  "grep -q \"UPDATE ark_ln_invoice SET status='paid', movement_id=15, received_sat=29840, fee_sat=160 WHERE payment_hash='${HASH}' AND status <> 'paid'\" '${SQL_LOG}' && ! grep -q 'INSERT INTO ark_receive' '${SQL_LOG}'"

NOTIFY_FAIL=1
ark_do_callbacks
check "failed callback counts a failure and stays due" \
  "grep -q 'UPDATE ark_ln_invoice SET callback_failures=callback_failures+1 WHERE id=5' '${SQL_LOG}' && ! grep -q 'SET calledback=true, calledback_ts' '${SQL_LOG}'"
NOTIFY_FAIL=
ark_do_callbacks
ark_do_callbacks
check "receive callback is posted once more and then marked delivered" \
  "[ \"\$(grep -c '^http://app/cb?a=1|2 ' '${NOTIFY_LOG}')\" -eq 2 ] && grep -q '^http://app/cb?a=1|2 {\"id\":5,\"event\":\"ark_lnreceive\",\"label\":\"order|123\",\"bolt11\":\"${INV}\",\"payment_hash\":\"${HASH}\",\"eventMessage\":\"ZXZlbnQ=\",\"msatoshi\":30000000,\"amount_received_msat\":29840000,\"fee_sat\":160,\"movementId\":15}$' '${NOTIFY_LOG}' && grep -q 'UPDATE ark_ln_invoice SET calledback=true, calledback_ts=CURRENT_TIMESTAMP WHERE id=5' '${SQL_LOG}'"
check "invoices without a callback URL are marked delivered" \
  "grep -q \"UPDATE ark_ln_invoice SET calledback=true WHERE NOT calledback AND status = 'paid' AND (callback_url IS NULL OR callback_url = '')\" '${SQL_LOG}'"

reset
SEND_EVENT=ZXZlbnQ=
ark_process_movement "$(send_movement successful)"
ark_process_movement "$(send_movement successful)"
check "send movement publishes the stored eventMessage exactly once" \
  "[ \"\$(grep -c '^ark_lnpay ' '${MQTT_LOG}')\" -eq 1 ] && grep -q '^ark_lnpay {\"payment_hash\":\"${HASH}\",\"movementId\":14,\"status\":\"complete\",\"eventMessage\":\"ZXZlbnQ=\"}$' '${MQTT_LOG}'"

reset
ark_process_movement "$(send_movement failed)"
check "failed send movement is recorded as failed" \
  "grep -q \"UPDATE ark_ln_send SET status='failed', movement_id=14, published=true WHERE payment_hash='${HASH}' AND NOT published\" '${SQL_LOG}'"

reset
ark_process_movement "$(send_movement pending)"
check "pending send movement is left alone" "! grep -q 'UPDATE ark_ln_send' '${SQL_LOG}'"

reset
PREPAID=1
ark_manage_missed
check "catch-up expires unpaid invoices past their expiry" \
  "grep -q \"UPDATE ark_ln_invoice SET status='expired' WHERE status='unpaid' AND expires_at IS NOT NULL AND expires_at < EXTRACT(EPOCH FROM NOW())\" '${SQL_LOG}'"
check "catch-up processes the send movement" \
  "grep -q \"UPDATE ark_ln_send SET status='complete', movement_id=14\" '${SQL_LOG}'"
PREPAID=

# --- an invoice paid on its Ark address ---------------------------------------

# barkd pays it with an arkoor: no Lightning send exists, and the movement is
# a bark.arkoor send to the invoice.
arkoor_movement='{"id":21,"status":"successful","subsystem":{"name":"bark.arkoor","kind":"send"},"metadata":{},"offchain_fee_sat":0,"sent_to":[{"destination":{"type":"invoice","value":"'${INV}'"},"amount_sat":1000}]}'
(
  barkd_call() {
    rm -f "$(barkd_http_code_file)"
    printf '%s %s %s\n' "${1}" "${2}" "${3:-}" >> "${BARKD_LOG}"
    case "${2}" in
      /wallet/connected) echo '{"connected":true}'; return 0 ;;
      /lightning/pay) echo "{\"message\":\"Payment sent\",\"payment_hash\":\"${HASH}\"}"; return 0 ;;
      /lightning/sends/*) printf 404 > "$(barkd_http_code_file)"; echo '{"message":"not found"}'; return 2 ;;
      /history*) if grep -q '^POST /lightning/pay' "${BARKD_LOG}" || [ -n "${PREPAID}" ]; then echo "[${arkoor_movement}]"; else echo '[]'; fi; return 0 ;;
    esac
  }
  reset
  out=$(ark_lnpay "{\"bolt11\":\"${INV}\",\"expected_msatoshi\":1000000}")
  check "an invoice paid on its Ark address is complete, without a preimage" \
    "jqcheck '${out}' '.status == \"complete\" and .movementId == 21 and .payment_preimage == null and .amount_msat == 1000000 and .amount_sent_msat == 1000000'"
  check "its send row is marked complete" "grep -q \"UPDATE ark_ln_send SET status='complete', movement_id=21\" '${SQL_LOG}'"
  reset
  SEND_EVENT=ZXZlbnQ=
  ark_process_movement "${arkoor_movement}"
  check "movement loop closes and publishes an Ark-address invoice payment" \
    "grep -q \"SELECT payment_hash FROM ark_ln_send WHERE destination='${INV}'\" '${SQL_LOG}' && grep -q \"UPDATE ark_ln_send SET status='complete', movement_id=21\" '${SQL_LOG}' && [ \"\$(grep -c '^ark_lnpay ' '${MQTT_LOG}')\" -eq 1 ]"
  reset
  PREPAID=1
  out=$(ark_lnpay "{\"bolt11\":\"${INV}\",\"expected_msatoshi\":1000000}")
  check "paying it again reports it already paid and pays nothing" \
    "jqcheck '${out}' '.status == \"complete\" and .already_paid == true' && ! grep -q '^POST /lightning/pay' '${BARKD_LOG}'"
  exit ${fail}
) || fail=1
PREPAID=

# --- invoices with an Ark address route hint -----------------------------------

# ln_pay itself, with the stubs put back over what its file defines.
. ./call_lightningd.sh
ln_call_lightningd() {
  printf '%s\n' "$*" >> "${CLN_LOG}"
  local routes='[]'
  [ "${HINT_MODE:-none}" = ark ] && routes='[[{"short_channel_id":"6386283x65536x0"}]]'
  echo "{\"type\":\"bolt11 invoice\",\"valid\":true,\"payment_hash\":\"${HASH}\",\"amount_msat\":${CLN_AMOUNT},\"description\":\"shape\",\"routes\":${routes}}"
}
ln_listpays() {
  echo '{"pays":[{"status":"complete","payment_hash":"cln"}]}'
}

# What the paymentalist answers, and with which Ark server it was asked.
MRH_LOG=$(mktemp)
MRH_MODE=ark
check_bolt11_mrh() {
  printf '%s|%s|%s\n' "${1}" "${2}" "${3}" >> "${MRH_LOG}"
  case "${MRH_MODE}" in
    ark) echo '{"result":{"liquid_address":null,"ark_address":"tark1hinted","amount_sats":1000,"original_invoice":"x"}}' ;;
    none) echo '{"result":{"liquid_address":null,"ark_address":null,"amount_sats":null,"original_invoice":"x"}}' ;;
    down) return 1 ;;
  esac
}
ark_info_barkd() {
  barkd_call() {
    printf '%s %s %s\n' "${1}" "${2}" "${3:-}" >> "${BARKD_LOG}"
    [ "${2}" = "/wallet/ark-info" ] && [ -n "${ARK_SERVER}" ] && { echo "{\"server_pubkey\":\"${ARK_SERVER}\"}"; return 0; }
    return 1
  }
}

reset; : > "${MRH_LOG}"
ARK_SERVER=02aa
( ark_info_barkd
  MRH_MODE=ark
  check "an Ark address of our Ark server is reported" "[ \"\$(ark_bolt11_address ${INV})\" = tark1hinted ]"
  check "the check is asked about our Ark server only" "grep -q '^${INV}||02aa\$' '${MRH_LOG}'"
  MRH_MODE=none
  check "an invoice without an Ark address has none" "[ -z \"\$(ark_bolt11_address ${INV})\" ]"
  MRH_MODE=down
  check "an unreachable check reports no Ark address" "[ -z \"\$(ark_bolt11_address ${INV})\" ]"
  ARK_SERVER=
  MRH_MODE=ark
  check "no Ark address without a known Ark server" "[ -z \"\$(ark_bolt11_address ${INV})\" ]"
  exit ${fail}
) || fail=1

# ln_pay hands a hinted invoice to the Ark wallet and nothing else.
ark_lnpay() { printf '%s' "${1}" > "${STATE}/ark_lnpay"; echo '{"status":"complete","via":"ark"}'; }
ark_bolt11_address() { [ "${MRH_MODE}" = "ark" ] && echo tark1hinted; return 0; }

reset
FEATURE_ARK=true MRH_MODE=ark HINT_MODE=ark
out=$(ln_pay "{\"bolt11\":\"${INV}\",\"expected_msatoshi\":1000000}")
check "ln_pay pays a hinted invoice from the Ark wallet" \
  "jqcheck '${out}' '.via == \"ark\"' && grep -q '\"bolt11\":\"${INV}\"' '${STATE}/ark_lnpay' && [ \"\$(grep -c '^decode ' '${CLN_LOG}')\" -eq 1 ] && ! grep -q '^pay ' '${CLN_LOG}'"

reset; : > "${MRH_LOG}"
FEATURE_ARK=true MRH_MODE=none HINT_MODE=none
out=$(ln_pay "{\"bolt11\":\"${INV}\",\"expected_msatoshi\":1000000}")
check "ln_pay pays an invoice without a hint over Lightning" \
  "jqcheck '${out}' '.payment_hash == \"cln\"' && [ ! -f '${STATE}/ark_lnpay' ] && [ ! -s '${MRH_LOG}' ] && ! grep -q '^GET /wallet/ark-info' '${BARKD_LOG}'"

reset
FEATURE_ARK=true MRH_MODE=down HINT_MODE=ark
out=$(ln_pay "{\"bolt11\":\"${INV}\",\"expected_msatoshi\":1000000}")
rc=$?
check "ln_pay refuses a hinted invoice when Ark lookup is down" \
  "[ ${rc} -eq 1 ] && jqcheck '${out}' '.error.code == -32003' && [ ! -f '${STATE}/ark_lnpay' ] && ! grep -q '^pay ' '${CLN_LOG}'"

reset
FEATURE_ARK=false MRH_MODE=ark HINT_MODE=ark
out=$(ln_pay "{\"bolt11\":\"${INV}\",\"expected_msatoshi\":1000000}")
check "ln_pay ignores the hint without the Ark feature" \
  "jqcheck '${out}' '.payment_hash == \"cln\"' && [ ! -f '${STATE}/ark_lnpay' ]"
rm -f "${MRH_LOG}"

exit ${fail}
