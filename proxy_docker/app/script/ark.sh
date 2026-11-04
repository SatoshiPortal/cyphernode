#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./sendtobarkd.sh

# Ark wallet operations through barkd. Amounts are in satoshis.

sql_quote() {
  printf '%s' "${1}" | sed "s/'/''/g"
}

ark_is_address() {
  printf '%s' "${1}" | grep -Eq '^(ark|tark)1[ac-hj-np-z02-9]{20,}$'
}

ark_getinfo() {
  trace "Entering ark_getinfo()..."

  local connected info fallback next_round returncode

  connected=$(barkd_call GET /wallet/connected)
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${connected}"
    return 1
  fi
  info=$(barkd_call GET /wallet/ark-info) || info='null'
  fallback=$(barkd_call GET /wallet/fallback) || fallback='null'
  next_round=$(barkd_call GET /wallet/next-round) || next_round='null'

  jq -cn --argjson connected "${connected}" --argjson info "${info}" \
    --argjson fallback "${fallback}" --argjson next_round "${next_round}" \
    '{connected: $connected.connected, ark_info: $info, fallback: $fallback, next_round: $next_round}'
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

# ark_send: {"destination":"ark1...","amount":12345,"label":"order-42"}
#
# The label is mandatory and unique. A repeated label returns the stored
# outcome instead of paying twice. A send whose outcome is unknown (barkd
# unreachable after the request) is reconciled by ark_manage_missed.
ark_send() {
  trace "Entering ark_send()..."

  local request=${1}
  local destination amount label
  local existing id response returncode movement_id status message

  destination=$(printf '%s' "${request}" | jq -r '.destination // empty')
  amount=$(printf '%s' "${request}" | jq -r '.amount // empty')
  label=$(printf '%s' "${request}" | jq -r '.label // empty')

  if [ -z "${destination}" ] || [ -z "${label}" ]; then
    echo '{"error":{"code":-32602,"message":"destination and label are required"}}'
    return 1
  fi
  case "${amount}" in
    ''|*[!0-9]*)
      echo '{"error":{"code":-32602,"message":"amount must be an integer number of satoshis"}}'
      return 1
      ;;
  esac
  if ! ark_is_address "${destination}"; then
    echo '{"error":{"code":-5,"message":"Invalid Ark address"}}'
    return 1
  fi

  existing=$(sql "SELECT id, status, movement_id, destination, amount_sat FROM ark_send WHERE label='$(sql_quote "${label}")'")
  if [ -n "${existing}" ]; then
    trace "[ark_send] duplicate label ${label}: ${existing}"
    printf '%s' "${existing}" | jq -Rc --arg label "${label}" '
      (. / "|") as $r |
      {error: {code: -32000, message: "duplicate label"},
       label: $label, id: ($r[0] | tonumber), status: $r[1],
       movementId: (if $r[2] == "" then null else ($r[2] | tonumber) end),
       destination: $r[3], amount_sat: ($r[4] | tonumber)}'
    return 1
  fi

  id=$(sql "INSERT INTO ark_send (label, destination, amount_sat, status) VALUES ('$(sql_quote "${label}")', '${destination}', ${amount}, 'pending') RETURNING id")
  if [ -z "${id}" ]; then
    echo '{"error":{"code":-32603,"message":"could not record the send"}}'
    return 1
  fi

  response=$(barkd_call POST /wallet/send "$(jq -cn --arg d "${destination}" --argjson a "${amount}" '{destination: $d, amount_sat: $a}')")
  returncode=$?
  if [ "${returncode}" -eq 1 ]; then
    # Transport failure: barkd may or may not have paid.
    sql "UPDATE ark_send SET status='unknown' WHERE id=${id}"
    jq -cn --argjson id "${id}" --arg label "${label}" '{error: {code: -32001, message: "barkd unreachable, outcome unknown; it will be reconciled"}, id: $id, label: $label, status: "unknown"}'
    return 1
  fi
  if [ "${returncode}" -ne 0 ]; then
    message=$(printf '%s' "${response}" | jq -r '.message // .error // "send failed"' 2>/dev/null)
    sql "UPDATE ark_send SET status='failed', error='$(sql_quote "${message}")' WHERE id=${id}"
    barkd_error "${returncode}" "${response}"
    return 1
  fi

  movement_id=$(ark_find_send_movement "${destination}" "${amount}")
  status="successful"
  sql "UPDATE ark_send SET status='${status}', movement_id=${movement_id:-NULL} WHERE id=${id}"
  message=$(printf '%s' "${response}" | jq -r '.message // ""')

  jq -cn --argjson id "${id}" --arg label "${label}" --arg d "${destination}" --argjson a "${amount}" \
    --arg status "${status}" --arg message "${message}" --argjson m "${movement_id:-null}" \
    '{id: $id, event: "ark_send", label: $label, destination: $d, amount_sat: $a, status: $status, movementId: $m, message: $message}'
}

# Most recent successful movement that paid amount to destination.
ark_find_send_movement() {
  local destination=${1}
  local amount=${2}
  local history

  history=$(barkd_call GET "/history?type=ark&value=${destination}") || return 1
  printf '%s' "${history}" | jq -r --arg d "${destination}" --argjson a "${amount}" '
    [ .[] | select(.status == "successful")
      | select(any(.sent_to[]; .destination.type == "ark" and .destination.value == $d and .amount_sat == $a)) ]
    | sort_by(.id) | last | .id // empty'
}

# ark_board: {"amount":100000,"label":"topup-1","callbackURL":"..."} or {"all":true,...}
ark_board() {
  trace "Entering ark_board()..."

  local request=${1}
  local amount all label callback_url callback_pg
  local response returncode txid vtxos id

  amount=$(printf '%s' "${request}" | jq -r '.amount // empty')
  all=$(printf '%s' "${request}" | jq -r '.all // false')
  label=$(printf '%s' "${request}" | jq -r '.label // empty')
  callback_url=$(printf '%s' "${request}" | jq -r '.callbackURL // empty')

  if [ -z "${label}" ]; then
    echo '{"error":{"code":-32602,"message":"label is required"}}'
    return 1
  fi
  if ark_job_label_exists "${label}"; then
    echo '{"error":{"code":-32000,"message":"duplicate label"}}'
    return 1
  fi

  if [ "${all}" = "true" ]; then
    response=$(barkd_call POST /boards/board-all)
    returncode=$?
  else
    case "${amount}" in
      ''|*[!0-9]*)
        echo '{"error":{"code":-32602,"message":"amount must be an integer number of satoshis, or all must be true"}}'
        return 1
        ;;
    esac
    response=$(barkd_call POST /boards/board-amount "$(jq -cn --argjson a "${amount}" '{amount_sat: $a}')")
    returncode=$?
  fi
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${response}"
    return 1
  fi

  txid=$(printf '%s' "${response}" | jq -r '.funding_tx.txid // empty')
  vtxos=$(printf '%s' "${response}" | jq -c '.vtxos // []')
  callback_pg=NULL
  [ -n "${callback_url}" ] && callback_pg="'$(sql_quote "${callback_url}")'"

  id=$(sql "INSERT INTO ark_job (kind, label, callback_url, txid, vtxos, status) VALUES ('board', '$(sql_quote "${label}")', ${callback_pg}, '${txid}', '$(sql_quote "${vtxos}")', 'pending') RETURNING id")

  jq -cn --argjson id "${id:-null}" --arg label "${label}" --arg txid "${txid}" --argjson vtxos "${vtxos}" \
    --arg cb "${callback_url}" \
    '{id: $id, event: "ark_board", label: $label, status: "pending", txid: $txid, vtxos: $vtxos, callbackURL: (if $cb == "" then null else $cb end)}'
}

# ark_offboard: {"vtxos":["..."],"address":"bc1...","label":"exit-1","callbackURL":"..."} or {"all":true,...}
ark_offboard() {
  trace "Entering ark_offboard()..."

  local request=${1}
  local vtxos all address label callback_url callback_pg body
  local response returncode txid movement_id id

  vtxos=$(printf '%s' "${request}" | jq -c '.vtxos // []')
  all=$(printf '%s' "${request}" | jq -r '.all // false')
  address=$(printf '%s' "${request}" | jq -r '.address // empty')
  label=$(printf '%s' "${request}" | jq -r '.label // empty')
  callback_url=$(printf '%s' "${request}" | jq -r '.callbackURL // empty')

  if [ -z "${label}" ]; then
    echo '{"error":{"code":-32602,"message":"label is required"}}'
    return 1
  fi
  if ark_job_label_exists "${label}"; then
    echo '{"error":{"code":-32000,"message":"duplicate label"}}'
    return 1
  fi

  if [ "${all}" = "true" ]; then
    body=$(jq -cn --arg a "${address}" '{address: (if $a == "" then null else $a end)}')
    response=$(barkd_call POST /wallet/offboard/all "${body}")
    returncode=$?
  else
    if [ "$(printf '%s' "${vtxos}" | jq 'length')" -eq 0 ]; then
      echo '{"error":{"code":-32602,"message":"vtxos must be a non-empty list, or all must be true"}}'
      return 1
    fi
    body=$(jq -cn --arg a "${address}" --argjson v "${vtxos}" '{address: (if $a == "" then null else $a end), vtxos: $v}')
    response=$(barkd_call POST /wallet/offboard/vtxos "${body}")
    returncode=$?
  fi
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${response}"
    return 1
  fi

  txid=$(printf '%s' "${response}" | jq -r '.offboard_txid // empty')
  movement_id=$(printf '%s' "${response}" | jq -r '.movement_id // empty')
  callback_pg=NULL
  [ -n "${callback_url}" ] && callback_pg="'$(sql_quote "${callback_url}")'"

  id=$(sql "INSERT INTO ark_job (kind, label, callback_url, txid, vtxos, movement_id, status) VALUES ('offboard', '$(sql_quote "${label}")', ${callback_pg}, '${txid}', '$(sql_quote "${vtxos}")', ${movement_id:-NULL}, 'pending') RETURNING id")

  jq -cn --argjson id "${id:-null}" --arg label "${label}" --arg txid "${txid}" --argjson m "${movement_id:-null}" \
    --arg cb "${callback_url}" \
    '{id: $id, event: "ark_offboard", label: $label, status: "pending", txid: $txid, movementId: $m, callbackURL: (if $cb == "" then null else $cb end)}'
}

ark_job_label_exists() {
  local existing
  existing=$(sql "SELECT id FROM ark_job WHERE label='$(sql_quote "${1}")'")
  [ -n "${existing}" ]
}

# ark_refresh: {"vtxos":["..."]} or {"all":true}
ark_refresh() {
  trace "Entering ark_refresh()..."

  local request=${1}
  local vtxos all

  vtxos=$(printf '%s' "${request}" | jq -c '.vtxos // []')
  all=$(printf '%s' "${request}" | jq -r '.all // false')

  if [ "${all}" = "true" ]; then
    ark_barkd_post /wallet/refresh/all
  else
    if [ "$(printf '%s' "${vtxos}" | jq 'length')" -eq 0 ]; then
      echo '{"error":{"code":-32602,"message":"vtxos must be a non-empty list, or all must be true"}}'
      return 1
    fi
    ark_barkd_post /wallet/refresh/vtxos "$(jq -cn --argjson v "${vtxos}" '{vtxos: $v}')"
  fi
}

ark_getjob() {
  trace "Entering ark_getjob(${1})..."

  local row
  row=$(sql "SELECT id, kind, label, status, txid, movement_id, vtxos, callback_url, calledback FROM ark_job WHERE label='$(sql_quote "${1}")'")
  if [ -z "${row}" ]; then
    echo '{"error":{"code":-32602,"message":"job not found"}}'
    return 1
  fi
  ark_job_row_json "${row}"
}

ark_job_row_json() {
  printf '%s' "${1}" | jq -Rc '
    (. / "|") as $r |
    {id: ($r[0] | tonumber), kind: $r[1], label: $r[2], status: $r[3], txid: $r[4],
     movementId: (if $r[5] == "" then null else ($r[5] | tonumber) end),
     vtxos: ($r[6] | fromjson? // []),
     callbackURL: (if $r[7] == "" then null else $r[7] end),
     calledback: ($r[8] == "t")}'
}

ark_getsend() {
  trace "Entering ark_getsend(${1})..."

  local row
  row=$(sql "SELECT id, label, destination, amount_sat, status, movement_id, error FROM ark_send WHERE label='$(sql_quote "${1}")'")
  if [ -z "${row}" ]; then
    echo '{"error":{"code":-32602,"message":"send not found"}}'
    return 1
  fi
  printf '%s' "${row}" | jq -Rc '
    (. / "|") as $r |
    {id: ($r[0] | tonumber), event: "ark_send", label: $r[1], destination: $r[2], amount_sat: ($r[3] | tonumber),
     status: $r[4], movementId: (if $r[5] == "" then null else ($r[5] | tonumber) end),
     error: (if $r[6] == "" then null else $r[6] end)}'
}
