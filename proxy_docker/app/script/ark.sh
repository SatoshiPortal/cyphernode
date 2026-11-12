#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./sendtobarkd.sh

# Ark wallet operations through barkd. Amounts are in satoshis.

sql_quote() {
  printf '%s' "${1}" | sed "s/'/''/g"
}

# Runs a SELECT and prints one JSON object per row, so values containing the
# psql field separator survive.
sql_json() {
  sql "SELECT row_to_json(t) FROM (${1}) t"
}

ark_is_address() {
  printf '%s' "${1}" | grep -Eq '^(ark|tark)1[ac-hj-np-z02-9]{20,}$'
}

ark_getinfo() {
  trace "Entering ark_getinfo()..."

  local connected info next_round balance vtxos history returncode

  connected=$(barkd_call GET /wallet/connected)
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${connected}"
    return 1
  fi
  info=$(barkd_call GET /wallet/ark-info) || info='null'
  next_round=$(barkd_call GET /wallet/next-round) || next_round='null'
  balance=$(barkd_call GET /wallet/balance) || balance='null'
  vtxos=$(barkd_call GET /wallet/vtxos) || vtxos='[]'
  history=$(barkd_call GET /history) || history='[]'

  # Health: money that is not spendable shows in balance, coins that need
  # merging in vtxos, and a wallet whose refresh keeps failing in
  # last_refresh. The coin and movement lists are too big for arguments.
  printf '%s\n%s\n' "${vtxos}" "${history}" | jq -cn --argjson connected "${connected}" --argjson info "${info}" \
    --argjson next_round "${next_round}" --argjson balance "${balance}" '
    input as $vtxos | input as $history
    | ([$vtxos[] | select(.state.type == "spendable")]) as $spendable
    | {connected: $connected.connected, ark_info: $info, next_round: $next_round,
       balance: $balance,
       vtxos: {count: ($vtxos | length), spendable: ($spendable | length),
               soonest_expiry_height: ([$spendable[].expiry_height] | min)},
       last_refresh: ([$history[] | select(.subsystem.kind == "refresh" and .status == "successful")]
                      | max_by(.id) | if . then {movementId: .id, completed_at: .time.completed_at} else null end)}'
}

# Simple passthroughs
ark_barkd_get() {
  trace "Entering ark_barkd_get(${1})..."

  local response returncode
  response=$(barkd_call GET "${1}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${response}"
    return 1
  fi
  printf '%s' "${response}"
}

ark_barkd_post() {
  trace "Entering ark_barkd_post(${1})..."

  local response returncode
  response=$(barkd_call POST "${1}" "${2}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${response}"
    return 1
  fi
  printf '%s' "${response}"
}

ark_getbalance() {
  ark_barkd_get /wallet/balance
}

ark_listvtxos() {
  ark_barkd_get /wallet/vtxos
}

ark_listmovements() {
  ark_barkd_get /history
}

ark_getmovement() {
  trace "Entering ark_getmovement(${1})..."

  local id=${1}
  local history movement

  case "${id}" in
    ''|*[!0-9]*)
      echo '{"error":{"code":-32602,"message":"movement id must be an integer"}}'
      return 1
      ;;
  esac

  history=$(ark_barkd_get /history) || { printf '%s' "${history}"; return 1; }
  movement=$(printf '%s' "${history}" | jq -c --argjson id "${id}" '.[] | select(.id == $id)')
  if [ -z "${movement}" ]; then
    echo '{"error":{"code":-32602,"message":"movement not found"}}'
    return 1
  fi
  printf '%s' "${movement}"
}

ark_getnewaddress() {
  ark_barkd_post /wallet/addresses/next
}

ark_onchain_getnewaddress() {
  ark_barkd_post /onchain/addresses/next
}

ark_onchain_getbalance() {
  ark_barkd_get /onchain/balance
}

# ark_send: {"destination":"ark1...","amount":12345,"eventMessage":"eyJ..."}
#
# Like spend: one call, one payment, the outcome in the reply. barkd does not
# return the movement it made, so the reply carries the one new successful
# movement to the destination for that amount, or null when there is none or
# more than one. Idempotency is the caller's, as with spend.
ark_send() {
  trace "Entering ark_send()..."

  local request=${1}
  local destination amount event_message
  local connected floor response returncode message movement_id

  destination=$(printf '%s' "${request}" | jq -r '.destination // empty')
  amount=$(printf '%s' "${request}" | jq -r '.amount // empty')
  event_message=$(printf '%s' "${request}" | jq -r '.eventMessage // empty')

  case "${amount}" in
    ''|*[!0-9]*|0*)
      echo '{"error":{"code":-32602,"message":"amount must be a positive integer number of satoshis"}}'
      return 1
      ;;
  esac
  if ! ark_is_address "${destination}"; then
    echo '{"error":{"code":-5,"message":"Invalid Ark address"}}'
    return 1
  fi

  # barkd reports a lost server connection as an invalid address.
  connected=$(barkd_call GET /wallet/connected)
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${connected}"
    return 1
  fi
  if [ "$(printf '%s' "${connected}" | jq -r '.connected')" != "true" ]; then
    echo '{"error":{"code":-32003,"message":"Ark server not connected; nothing was sent"}}'
    return 1
  fi

  floor=$(barkd_call GET "/history?type=ark&value=${destination}" | jq 'if type == "array" then [.[].id] | max // 0 else empty end')
  response=$(barkd_call POST /wallet/send "$(jq -cn --arg d "${destination}" --argjson a "${amount}" '{destination: $d, amount_sat: $a}')")
  returncode=$?
  trace "[ark_send] response=${response}"
  if [ "${returncode}" -eq 1 ]; then
    # Transport failure: barkd may or may not have paid.
    echo '{"error":{"code":-32001,"message":"barkd unreachable, outcome unknown; check ark_listmovements"}}'
    return 1
  fi
  if [ "${returncode}" -ne 0 ]; then
    message=$(printf '%s' "${response}" | jq -r '.message // empty' 2>/dev/null)
    case "${message}" in
      "Insufficient money available"*)
        trace "[ark_send] mosquitto_pub -h broker -t insufficientfunds"
        mosquitto_pub -h broker -t insufficientfunds -m "$(jq -cn --arg m "${message}" '{method: "ark_send", error: $m}')"
        ;;
    esac
    barkd_error "${returncode}" "${response}"
    return 1
  fi

  message=$(printf '%s' "${response}" | jq -r '.message // ""')
  movement_id=
  [ -n "${floor}" ] && movement_id=$(ark_find_send_movement "${destination}" "${amount}" "${floor}")

  if [ -n "${event_message}" ]; then
    trace "[ark_send] mosquitto_pub -h broker -t ark_send"
    mosquitto_pub -h broker -t ark_send -m "$(jq -cn --arg d "${destination}" --argjson a "${amount}" \
      --argjson m "${movement_id:-null}" --arg e "${event_message}" \
      '{destination: $d, amount_sat: $a, movementId: $m, eventMessage: $e}')"
  fi

  jq -cn --arg d "${destination}" --argjson a "${amount}" --argjson m "${movement_id:-null}" --arg message "${message}" \
    '{status: "accepted", movementId: $m, details: {destination: $d, amount_sat: $a, message: $message}}'
}

# ark_find_send_movement <destination> <amount> <floor>
# The one successful movement after the floor that paid amount to the
# destination; nothing when there is none or more than one.
ark_find_send_movement() {
  barkd_call GET "/history?type=ark&value=${1}" | jq -r --arg d "${1}" --argjson a "${2}" --argjson f "${3}" '
    [ .[] | select(.status == "successful" and .id > $f)
      | select(any(.sent_to[]; .destination.type == "ark" and .destination.value == $d and .amount_sat == $a)) ]
    | if length == 1 then .[0].id else empty end'
}

# ark_board: {"amount":100000,"label":"topup-1","callbackURL":"..."} or {"all":true,...}
#
# The job is recorded before barkd is called so a repeated label cannot board
# twice. A refusal leaves the job failed with barkd's message.
ark_board() {
  trace "Entering ark_board()..."

  local request=${1}
  local amount all label callback_url
  local response returncode txid vtxos id

  amount=$(printf '%s' "${request}" | jq -r '.amount // empty')
  all=$(printf '%s' "${request}" | jq -r '.all // false')
  label=$(printf '%s' "${request}" | jq -r '.label // empty')
  callback_url=$(printf '%s' "${request}" | jq -r '.callbackURL // empty')

  if [ "${all}" != "true" ]; then
    case "${amount}" in
      ''|*[!0-9]*|0*)
        echo '{"error":{"code":-32602,"message":"amount must be a positive integer number of satoshis, or all must be true"}}'
        return 1
        ;;
    esac
  fi
  id=$(ark_job_insert board "${label}" "${callback_url}") || { printf '%s' "${id}"; return 1; }

  if [ "${all}" = "true" ]; then
    response=$(barkd_call POST /boards/board-all)
    returncode=$?
  else
    response=$(barkd_call POST /boards/board-amount "$(jq -cn --argjson a "${amount}" '{amount_sat: $a}')")
    returncode=$?
  fi
  if [ "${returncode}" -ne 0 ]; then
    ark_job_fail "${id}" "${returncode}" "${response}"
    return 1
  fi

  txid=$(printf '%s' "${response}" | jq -r '.funding_tx.txid // empty')
  vtxos=$(printf '%s' "${response}" | jq -c '.vtxos // []')
  sql "UPDATE ark_job SET txid='${txid}', vtxos='$(sql_quote "${vtxos}")' WHERE id=${id}" > /dev/null

  jq -cn --argjson id "${id}" --arg lbl "${label}" --arg txid "${txid}" --argjson vtxos "${vtxos}" \
    --arg cb "${callback_url}" \
    '{id: $id, event: "ark_board", "label": $lbl, status: "pending", txid: $txid, vtxos: $vtxos, callbackURL: (if $cb == "" then null else $cb end)}'
}

# ark_offboard: {"vtxos":["..."],"address":"bc1...","label":"exit-1","callbackURL":"..."} or {"all":true,...}
ark_offboard() {
  trace "Entering ark_offboard()..."

  local request=${1}
  local vtxos all address label callback_url body
  local response returncode txid movement_id id

  vtxos=$(printf '%s' "${request}" | jq -c '.vtxos // []')
  all=$(printf '%s' "${request}" | jq -r '.all // false')
  address=$(printf '%s' "${request}" | jq -r '.address // empty')
  label=$(printf '%s' "${request}" | jq -r '.label // empty')
  callback_url=$(printf '%s' "${request}" | jq -r '.callbackURL // empty')

  if [ "${all}" != "true" ] && [ "$(printf '%s' "${vtxos}" | jq 'length')" -eq 0 ]; then
    echo '{"error":{"code":-32602,"message":"vtxos must be a non-empty list, or all must be true"}}'
    return 1
  fi
  id=$(ark_job_insert offboard "${label}" "${callback_url}" "${vtxos}") || { printf '%s' "${id}"; return 1; }

  if [ "${all}" = "true" ]; then
    body=$(jq -cn --arg a "${address}" '{address: (if $a == "" then null else $a end)}')
    response=$(barkd_call POST /wallet/offboard/all "${body}")
    returncode=$?
  else
    body=$(jq -cn --arg a "${address}" --argjson v "${vtxos}" '{address: (if $a == "" then null else $a end), vtxos: $v}')
    response=$(barkd_call POST /wallet/offboard/vtxos "${body}")
    returncode=$?
  fi
  if [ "${returncode}" -ne 0 ]; then
    ark_job_fail "${id}" "${returncode}" "${response}"
    return 1
  fi

  txid=$(printf '%s' "${response}" | jq -r '.offboard_txid // empty')
  movement_id=$(printf '%s' "${response}" | jq -r '.movement_id // empty')
  sql "UPDATE ark_job SET txid='${txid}', movement_id=${movement_id:-NULL} WHERE id=${id}" > /dev/null

  jq -cn --argjson id "${id}" --arg lbl "${label}" --arg txid "${txid}" --argjson m "${movement_id:-null}" \
    --arg cb "${callback_url}" \
    '{id: $id, event: "ark_offboard", "label": $lbl, status: "pending", txid: $txid, movementId: $m, callbackURL: (if $cb == "" then null else $cb end)}'
}

# ark_job_insert <kind> <label> <callback url> [vtxos json]
# Prints the new job id, or an error document with a non-zero return.
ark_job_insert() {
  local kind=${1}
  local label=${2}
  local callback_url=${3}
  local vtxos=${4:-[]}
  local callback_pg=NULL
  local id

  if [ -z "${label}" ]; then
    echo '{"error":{"code":-32602,"message":"label is required"}}'
    return 1
  fi
  [ -n "${callback_url}" ] && callback_pg="'$(sql_quote "${callback_url}")'"
  id=$(sql "INSERT INTO ark_job (kind, label, callback_url, vtxos, status) VALUES ('${kind}', '$(sql_quote "${label}")', ${callback_pg}, '$(sql_quote "${vtxos}")', 'pending') ON CONFLICT (label) DO NOTHING RETURNING id")
  if [ -z "${id}" ]; then
    echo '{"error":{"code":-32000,"message":"duplicate label"}}'
    return 1
  fi
  printf '%s' "${id}"
}

# ark_job_fail <job id> <barkd_call rc> <barkd body>
ark_job_fail() {
  local message
  message=$(printf '%s' "${3}" | jq -r '.message // .error // "request failed"' 2>/dev/null)
  [ -z "${message}" ] && message="barkd unreachable"
  sql "UPDATE ark_job SET status='failed', error='$(sql_quote "${message}")' WHERE id=${1}" > /dev/null
  barkd_error "${2}" "${3}"
}

ark_getjob() {
  trace "Entering ark_getjob(${1})..."

  local row
  row=$(sql_json "SELECT id, kind, label, status, txid, movement_id, vtxos, callback_url, calledback, error FROM ark_job WHERE label='$(sql_quote "${1}")'")
  if [ -z "${row}" ]; then
    echo '{"error":{"code":-32602,"message":"job not found"}}'
    return 1
  fi
  ark_job_row_json "${row}"
}

# ark_job_row_json <json row from sql_json>
ark_job_row_json() {
  printf '%s' "${1}" | jq -c '
    {id: .id, kind: .kind, "label": .label, status: .status, txid: .txid,
     movementId: .movement_id, vtxos: (.vtxos | fromjson? // []),
     callbackURL: .callback_url, calledback: .calledback, error: .error}'
}

# Lightning through the Ark wallet. barkd asks the Ark server's node to pay
# or to hold an inbound HTLC; the proxy only asks and observes. Amounts in
# the requests and replies are in millisatoshis, as in ln_pay and
# ln_create_invoice.

ark_is_bolt11() {
  printf '%s' "${1}" | grep -Eiq '^ln(bc|tb|tbs|bcrt)[0-9]*[munp]?1[ac-hj-np-z02-9]+$'
}

# ark_bolt11_amount_msat <bolt11>
# The amount from the human-readable part; nothing for an amount-less invoice.
ark_bolt11_amount_msat() {
  local hrp amount unit

  hrp=${1%1*}
  hrp=$(printf '%s' "${hrp}" | tr 'A-Z' 'a-z' | sed -E 's/^ln(bcrt|tbs|tb|bc)//')
  [ -n "${hrp}" ] || return 0
  case "${hrp}" in
    *[munp]) amount=${hrp%?}; unit=${hrp#"${amount}"} ;;
    *) amount=${hrp}; unit= ;;
  esac
  case "${amount}" in
    ''|*[!0-9]*) return 0 ;;
  esac
  case "${unit}" in
    m) printf '%s' "$((amount * 100000000))" ;;
    u) printf '%s' "$((amount * 100000))" ;;
    n) printf '%s' "$((amount * 100))" ;;
    p) printf '%s' "$((amount / 10))" ;;
    '') printf '%s' "$((amount * 100000000000))" ;;
  esac
}

# ark_ln_find_send_movement <payment hash> [bolt11]
# The newest bark.lightning_send movement for the payment hash, or for the
# invoice when the hash is not known. Prints nothing when there is none.
ark_ln_find_send_movement() {
  local path=/history
  [ -n "${2:-}" ] && path="/history?type=invoice&value=${2}"
  barkd_call GET "${path}" | jq -c --arg h "${1}" '
    if type == "array" then
      [ .[] | select(.subsystem.name == "bark.lightning_send" and ($h == "" or .metadata.payment_hash == $h)) ]
      | max_by(.id) // empty
    else empty end'
}

# ark_ln_send_reply <status> <payment hash> <destination> <amount msat> [movement json] [already paid]
ark_ln_send_reply() {
  printf '%s' "${5:-null}" | jq -c --arg s "${1}" --arg h "${2}" --arg d "${3}" --arg a "${4}" --arg ap "${6:-}" '
    {status: $s, payment_hash: (if $h == "" then null else $h end),
     payment_preimage: (.metadata.payment_preimage? // null),
     amount_msat: (if ((.sent_to? // []) | length) > 0 then .sent_to[0].amount_sat * 1000 elif $a == "" then null else ($a | tonumber) end),
     amount_sent_msat: (if ((.sent_to? // []) | length) > 0 then (.sent_to[0].amount_sat + .offchain_fee_sat) * 1000 else null end),
     movementId: (.id? // null), destination: $d}
    + (if $ap == "true" then {already_paid: true} else {} end)'
}

# ark_ln_send_finish <payment hash> <complete|failed> [movement id]
# Records the outcome and publishes the eventMessage once: the row is claimed
# with published=true in the same statement, so the movement loop and
# ark_lnpay cannot both publish.
ark_ln_send_finish() {
  local event_message

  [ -n "${1}" ] || return 0
  event_message=$(sql "UPDATE ark_ln_send SET status='${2}', movement_id=${3:-NULL}, published=true"\
" WHERE payment_hash='$(sql_quote "${1}")' AND NOT published RETURNING COALESCE(event_message, '')")
  [ -n "${event_message}" ] || return 0

  trace "[ark_ln_send_finish] mosquitto_pub -h broker -t ark_lnpay"
  mosquitto_pub -h broker -t ark_lnpay -m "$(jq -cn --arg h "${1}" --arg s "${2}" --argjson m "${3:-null}" --arg e "${event_message}" \
    '{payment_hash: $h, movementId: $m, status: $s, eventMessage: $e}')"
}

# ark_lnpay: {"destination":"lnbc...","expected_msatoshi":"40000000","expected_description":"order #1","eventMessage":"eyJ..."}
#
# Like ln_pay: the amount and description are checked against the invoice,
# an invoice already paid or being paid is reported instead of paid again,
# and the call waits up to 85 seconds for the outcome. The destination can
# also be a BOLT12 offer, a Lightning address or an LNURL; those and
# amount-less invoices are paid for expected_msatoshi.
#
# The invoice amount comes from the bolt11 human-readable part. With the
# lightning feature, Cyphernode's own CLN also decodes the invoice for the
# description check and the payment hash; without it, the description is
# not checked and the payment hash comes from barkd's reply.
ark_lnpay() {
  trace "Entering ark_lnpay()..."

  local request=${1}
  local destination expected_msatoshi expected_description event_message
  local bolt11 invoice_msat amount_sat payment_hash decoded description event_pg
  local connected movement response returncode message body
  local deadline status send

  destination=$(printf '%s' "${request}" | jq -r '.destination // .bolt11 // empty')
  expected_msatoshi=$(printf '%s' "${request}" | jq -r '.expected_msatoshi // .expectedMsatoshi // empty')
  expected_description=$(printf '%s' "${request}" | jq -r '.expected_description // .expectedDescription // empty')
  event_message=$(printf '%s' "${request}" | jq -r '.eventMessage // empty')

  if [ -z "${destination}" ]; then
    echo '{"error":{"code":-32602,"message":"destination is required"}}'
    return 1
  fi
  case "${expected_msatoshi}" in
    *[!0-9]*|0*)
      echo '{"error":{"code":-32602,"message":"expected_msatoshi must be a positive integer number of millisatoshis"}}'
      return 1
      ;;
  esac

  bolt11=
  invoice_msat=
  payment_hash=
  if ark_is_bolt11 "${destination}"; then
    bolt11=${destination}
    invoice_msat=$(ark_bolt11_amount_msat "${bolt11}")
    if [ "${FEATURE_LIGHTNING}" = "true" ]; then
      decoded=$(ln_call_lightningd decode "${bolt11}")
      if [ "$?" -ne 0 ] || [ "$(printf '%s' "${decoded}" | jq -r '.valid')" = "false" ]; then
        echo '{"error":{"code":-32602,"message":"invalid bolt11 invoice"}}'
        return 1
      fi
      payment_hash=$(printf '%s' "${decoded}" | jq -r '.payment_hash // empty')
      description=$(printf '%s' "${decoded}" | jq -r '.description // empty')
      if [ -n "${expected_description}" ] && [ "${expected_description}" != "${description}" ]; then
        trace "[ark_lnpay] expected_description does not match the invoice"
        echo '{"error":{"code":-32602,"message":"expected_description does not match the invoice description"}}'
        return 1
      fi
    fi
  fi

  if [ -n "${invoice_msat}" ]; then
    if [ -n "${expected_msatoshi}" ] && [ "${expected_msatoshi}" != "${invoice_msat}" ]; then
      trace "[ark_lnpay] expected_msatoshi ${expected_msatoshi} does not match the invoice ${invoice_msat}"
      jq -cn --argjson e "${expected_msatoshi}" --argjson i "${invoice_msat}" \
        '{error: {code: -32602, message: "expected_msatoshi does not match the invoice amount", data: {expected_msatoshi: $e, invoice_msatoshi: $i}}}'
      return 1
    fi
    amount_sat=
  else
    if [ -z "${expected_msatoshi}" ]; then
      echo '{"error":{"code":-32602,"message":"expected_msatoshi is required for a destination without an amount"}}'
      return 1
    fi
    if [ "$((expected_msatoshi % 1000))" -ne 0 ]; then
      echo '{"error":{"code":-32602,"message":"expected_msatoshi must be a whole number of satoshis"}}'
      return 1
    fi
    amount_sat=$((expected_msatoshi / 1000))
  fi

  # Already paid or in flight: only an invoice can be looked up before paying.
  if [ -n "${bolt11}" ]; then
    movement=$(ark_ln_find_send_movement "${payment_hash}" "${bolt11}")
    case "$(printf '%s' "${movement}" | jq -r '.status // empty')" in
      successful)
        ark_ln_send_reply complete "$(printf '%s' "${movement}" | jq -r '.metadata.payment_hash // empty')" "${destination}" "" "${movement}" true
        return 0
        ;;
      pending)
        ark_ln_send_reply pending "$(printf '%s' "${movement}" | jq -r '.metadata.payment_hash // empty')" "${destination}" "" "${movement}" true
        return 1
        ;;
    esac
  fi

  # barkd reports a lost server connection as an invalid destination.
  connected=$(barkd_call GET /wallet/connected)
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${connected}"
    return 1
  fi
  if [ "$(printf '%s' "${connected}" | jq -r '.connected')" != "true" ]; then
    echo '{"error":{"code":-32003,"message":"Ark server not connected; nothing was sent"}}'
    return 1
  fi

  body=$(jq -cn --arg d "${destination}" --arg a "${amount_sat}" '{destination: $d} + (if $a == "" then {} else {amount_sat: ($a | tonumber)} end)')
  response=$(barkd_call POST /lightning/pay "${body}")
  returncode=$?
  trace "[ark_lnpay] response=${response}"
  if [ "${returncode}" -eq 1 ]; then
    # Transport failure: barkd may or may not have paid.
    echo '{"error":{"code":-32001,"message":"barkd unreachable, outcome unknown; check ark_listmovements"}}'
    return 1
  fi
  if [ "${returncode}" -ne 0 ]; then
    message=$(printf '%s' "${response}" | jq -r '.message // empty' 2>/dev/null)
    case "${message}" in
      "Insufficient money available"*)
        trace "[ark_lnpay] mosquitto_pub -h broker -t insufficientfunds"
        mosquitto_pub -h broker -t insufficientfunds -m "$(jq -cn --arg m "${message}" '{method: "ark_lnpay", error: $m}')"
        ;;
    esac
    barkd_error "${returncode}" "${response}"
    return 1
  fi

  [ -z "${payment_hash}" ] && payment_hash=$(printf '%s' "${response}" | jq -r '.payment_hash // empty')
  if [ -z "${payment_hash}" ]; then
    ark_ln_send_reply pending "" "${destination}" "${invoice_msat:-${expected_msatoshi}}"
    return 0
  fi

  # The eventMessage is kept for the movement loop in case the outcome
  # arrives after the wait below. A retry of a failed send reuses the row.
  event_pg=NULL; [ -n "${event_message}" ] && event_pg="'$(sql_quote "${event_message}")'"
  sql "INSERT INTO ark_ln_send (payment_hash, event_message, status) VALUES ('${payment_hash}', ${event_pg}, 'pending')"\
" ON CONFLICT (payment_hash) DO UPDATE SET event_message=EXCLUDED.event_message, status='pending', movement_id=NULL, published=false" > /dev/null

  # A failed send ends in state unknown once its HTLCs are revoked, so
  # failure is read from the movement.
  deadline=$(( $(date +%s) + ${ARK_LNPAY_WAIT:-85} ))
  status=pending
  while :; do
    send=$(barkd_call GET "/lightning/sends/${payment_hash}")
    if [ "$?" -eq 0 ] && [ "$(printf '%s' "${send}" | jq -r '.state')" = "paid" ]; then
      status=complete
      break
    fi
    movement=$(ark_ln_find_send_movement "${payment_hash}" "${bolt11}")
    if [ "$(printf '%s' "${movement}" | jq -r '.status // empty')" = "failed" ]; then
      status=failed
      break
    fi
    [ "$(date +%s)" -ge "${deadline}" ] && break
    sleep "${ARK_LNPAY_POLL:-2}"
  done
  trace "[ark_lnpay] payment_hash=${payment_hash} status=${status}"

  if [ "${status}" != "pending" ]; then
    [ "${status}" = "complete" ] && movement=$(ark_ln_find_send_movement "${payment_hash}" "${bolt11}")
    ark_ln_send_finish "${payment_hash}" "${status}" "$(printf '%s' "${movement}" | jq -r '.id // empty')"
  fi

  ark_ln_send_reply "${status}" "${payment_hash}" "${destination}" "${invoice_msat:-${expected_msatoshi}}" "${movement}"
  [ "${status}" = "failed" ] && return 1
  return 0
}

# ark_lncreateinvoice: {"msatoshi":"30000000","label":"order-123","description":"Bull order #123","expiry":"900","callbackUrl":"...","eventMessage":"eyJ..."}
#
# Like ln_create_invoice, paid into the Ark wallet. The label is recorded
# before barkd is called so a repeated label cannot create two invoices. The
# amount received is the invoice amount minus the server's lightning_receive
# fee (see ark_getinfo); the callback reports both.
ark_lncreateinvoice() {
  trace "Entering ark_lncreateinvoice()..."

  local request=${1}
  local msatoshi label description expiry callback_url event_message
  local amount_sat callback_pg event_pg description_pg expires_pg
  local id body response returncode bolt11 decoded info payment_hash expires_at

  msatoshi=$(printf '%s' "${request}" | jq -r '.msatoshi // empty')
  label=$(printf '%s' "${request}" | jq -r '.label // empty')
  description=$(printf '%s' "${request}" | jq -r '.description // empty')
  expiry=$(printf '%s' "${request}" | jq -r '.expiry // empty')
  callback_url=$(printf '%s' "${request}" | jq -r '.callbackUrl // .callbackURL // empty')
  event_message=$(printf '%s' "${request}" | jq -r '.eventMessage // empty')

  case "${msatoshi}" in
    ''|*[!0-9]*|0*)
      echo '{"error":{"code":-32602,"message":"msatoshi must be a positive integer number of millisatoshis"}}'
      return 1
      ;;
  esac
  if [ "$((msatoshi % 1000))" -ne 0 ]; then
    echo '{"error":{"code":-32602,"message":"msatoshi must be a whole number of satoshis"}}'
    return 1
  fi
  amount_sat=$((msatoshi / 1000))
  if [ -z "${label}" ]; then
    echo '{"error":{"code":-32602,"message":"label is required"}}'
    return 1
  fi
  case "${expiry}" in
    *[!0-9]*|0*)
      echo '{"error":{"code":-32602,"message":"expiry must be a positive integer number of seconds"}}'
      return 1
      ;;
  esac

  callback_pg=NULL; [ -n "${callback_url}" ] && callback_pg="'$(sql_quote "${callback_url}")'"
  event_pg=NULL; [ -n "${event_message}" ] && event_pg="'$(sql_quote "${event_message}")'"
  description_pg=NULL; [ -n "${description}" ] && description_pg="'$(sql_quote "${description}")'"
  id=$(sql "INSERT INTO ark_ln_invoice (label, amount_sat, description, callback_url, event_message, status)"\
" VALUES ('$(sql_quote "${label}")', ${amount_sat}, ${description_pg}, ${callback_pg}, ${event_pg}, 'unpaid')"\
" ON CONFLICT (label) DO NOTHING RETURNING id")
  if [ -z "${id}" ]; then
    echo '{"error":{"code":-32000,"message":"duplicate label"}}'
    return 1
  fi

  body=$(jq -cn --argjson a "${amount_sat}" --arg d "${description}" --arg e "${expiry}" \
    '{amount_sat: $a} + (if $d == "" then {} else {description: $d} end) + (if $e == "" then {} else {expiry_secs: ($e | tonumber)} end)')
  response=$(barkd_call POST /lightning/receives/invoice "${body}")
  returncode=$?
  trace "[ark_lncreateinvoice] response=${response}"
  if [ "${returncode}" -ne 0 ]; then
    sql "DELETE FROM ark_ln_invoice WHERE id=${id}" > /dev/null
    barkd_error "${returncode}" "${response}"
    return 1
  fi
  bolt11=$(printf '%s' "${response}" | jq -r '.invoice // empty')

  # With the lightning feature, Cyphernode's own CLN decodes the invoice:
  # the payment hash and the exact expiry, which barkd caps at the server's.
  # Without it, barkd's receive status gives the payment hash and the
  # expiry is the one requested.
  payment_hash=
  expires_at=
  if [ "${FEATURE_LIGHTNING}" = "true" ]; then
    decoded=$(ln_call_lightningd decode "${bolt11}")
    payment_hash=$(printf '%s' "${decoded}" | jq -r '.payment_hash // empty')
    expires_at=$(printf '%s' "${decoded}" | jq -r 'if .created_at and .expiry then .created_at + .expiry else empty end')
  fi
  if [ -z "${payment_hash}" ]; then
    info=$(barkd_call GET "/lightning/receives/${bolt11}")
    payment_hash=$(printf '%s' "${info}" | jq -r '.payment_hash // empty')
  fi
  [ -z "${expires_at}" ] && [ -n "${expiry}" ] && expires_at=$(( $(date +%s) + expiry ))

  expires_pg=NULL; [ -n "${expires_at}" ] && expires_pg=${expires_at}
  sql "UPDATE ark_ln_invoice SET bolt11='${bolt11}', payment_hash='${payment_hash}', expires_at=${expires_pg} WHERE id=${id}" > /dev/null

  jq -cn --argjson id "${id}" --arg lbl "${label}" --arg b "${bolt11}" --arg h "${payment_hash}" --argjson msat "${msatoshi}" \
    --arg d "${description}" --arg x "${expires_at}" --arg cb "${callback_url}" \
    '{id: $id, "label": $lbl, bolt11: $b, payment_hash: (if $h == "" then null else $h end), msatoshi: $msat, amount_msat: $msat,
      description: (if $d == "" then null else $d end), status: "unpaid",
      expires_at: (if $x == "" then null else ($x | tonumber) end), callbackUrl: (if $cb == "" then null else $cb end)}'
}

ark_lngetinvoice() {
  trace "Entering ark_lngetinvoice(${1})..."

  local row bolt11 info state

  row=$(sql_json "SELECT id, label, bolt11, payment_hash, amount_sat, description, expires_at, callback_url, event_message,"\
" status, movement_id, received_sat, fee_sat, calledback FROM ark_ln_invoice WHERE label='$(sql_quote "${1}")'")
  if [ -z "${row}" ]; then
    echo '{"error":{"code":-32602,"message":"invoice not found"}}'
    return 1
  fi

  # barkd forgets a receive once it is settled or canceled.
  bolt11=$(printf '%s' "${row}" | jq -r '.bolt11 // empty')
  state=null
  if [ -n "${bolt11}" ]; then
    info=$(barkd_call GET "/lightning/receives/${bolt11}") && state=$(printf '%s' "${info}" | jq -c '.state')
  fi

  printf '%s' "${row}" | jq -c --argjson state "${state:-null}" '
    {id: .id, "label": .label, bolt11: .bolt11, payment_hash: .payment_hash, msatoshi: (.amount_sat * 1000), amount_msat: (.amount_sat * 1000),
     description: .description, status: .status, expires_at: .expires_at, callbackUrl: .callback_url, eventMessage: .event_message,
     movementId: .movement_id, amount_received_msat: (if .received_sat then .received_sat * 1000 else null end), fee_sat: .fee_sat,
     calledback: .calledback, receive_state: $state}'
}
