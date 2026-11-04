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
# unreachable after the request) is reconciled by ark_manage_missed. The
# movement floor is the newest movement to the destination before the send,
# so a movement is only matched to this send if it came after it.
ark_send() {
  trace "Entering ark_send()..."

  local request=${1}
  local destination amount label
  local existing id floor history response returncode movement_id status message connected result

  destination=$(printf '%s' "${request}" | jq -r '.destination // empty')
  amount=$(printf '%s' "${request}" | jq -r '.amount // empty')
  label=$(printf '%s' "${request}" | jq -r '.label // empty')

  if [ -z "${destination}" ] || [ -z "${label}" ]; then
    echo '{"error":{"code":-32602,"message":"destination and label are required"}}'
    return 1
  fi
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

  existing=$(sql_json "SELECT id, status, movement_id, destination, amount_sat FROM ark_send WHERE label='$(sql_quote "${label}")'")
  if [ -n "${existing}" ]; then
    trace "[ark_send] duplicate label ${label}: ${existing}"
    printf '%s' "${existing}" | jq -c --arg lbl "${label}" '
      {error: {code: -32000, message: "duplicate label"},
       "label": $lbl, id: .id, status: .status, movementId: .movement_id,
       destination: .destination, amount_sat: .amount_sat}'
    return 1
  fi

  # barkd reports a lost server connection as an invalid address; refuse up
  # front so the caller can retry under the same label.
  connected=$(barkd_call GET /wallet/connected)
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${connected}"
    return 1
  fi
  if [ "$(printf '%s' "${connected}" | jq -r '.connected')" != "true" ]; then
    echo '{"error":{"code":-32003,"message":"Ark server not connected; nothing was sent, retry later"}}'
    return 1
  fi

  history=$(barkd_call GET "/history?type=ark&value=${destination}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    barkd_error "${returncode}" "${history}"
    return 1
  fi
  floor=$(printf '%s' "${history}" | jq '[.[].id] | max // 0')

  id=$(sql "INSERT INTO ark_send (label, destination, amount_sat, status, movement_floor) VALUES ('$(sql_quote "${label}")', '${destination}', ${amount}, 'pending', ${floor}) ON CONFLICT (label) DO NOTHING RETURNING id")
  if [ -z "${id}" ]; then
    echo '{"error":{"code":-32000,"message":"duplicate label"}}'
    return 1
  fi

  # Sends are serialized: concurrent sends can pick the same coin in barkd,
  # and a movement is claimed before the next send can create a look-alike.
  result=$( {
    flock --timeout 120 9 || { printf '3\n\n'; exit 0; }
    response=$(barkd_call POST /wallet/send "$(jq -cn --arg d "${destination}" --argjson a "${amount}" '{destination: $d, amount_sat: $a}')")
    returncode=$?
    movement_id=
    [ "${returncode}" -eq 0 ] && movement_id=$(ark_record_send_movement "${id}" "${destination}" "${amount}" "${floor}")
    printf '%s\n%s\n%s' "${returncode}" "${movement_id}" "${response}"
  } 9>./.ark_send.lock )
  returncode=$(printf '%s\n' "${result}" | sed -n 1p)
  movement_id=$(printf '%s\n' "${result}" | sed -n 2p)
  response=$(printf '%s\n' "${result}" | sed -n '3,$p')
  if [ "${returncode}" -eq 3 ]; then
    sql "UPDATE ark_send SET status='failed', error='another send is in progress, retry' WHERE id=${id}"
    echo '{"error":{"code":-32002,"message":"another send is in progress, retry under a new label"}}'
    return 1
  fi
  if [ "${returncode}" -eq 1 ]; then
    # Transport failure: barkd may or may not have paid.
    sql "UPDATE ark_send SET status='unknown' WHERE id=${id}"
    jq -cn --argjson id "${id}" --arg lbl "${label}" '{error: {code: -32001, message: "barkd unreachable, outcome unknown; it will be reconciled"}, id: $id, "label": $lbl, status: "unknown"}'
    return 1
  fi
  if [ "${returncode}" -ne 0 ]; then
    message=$(printf '%s' "${response}" | jq -r '.message // .error // "send failed"' 2>/dev/null)
    sql "UPDATE ark_send SET status='failed', error='$(sql_quote "${message}")' WHERE id=${id}"
    barkd_error "${returncode}" "${response}"
    return 1
  fi

  status="successful"
  sql "UPDATE ark_send SET status='${status}' WHERE id=${id}"
  message=$(printf '%s' "${response}" | jq -r '.message // ""')

  jq -cn --argjson id "${id}" --arg lbl "${label}" --arg d "${destination}" --argjson a "${amount}" \
    --arg status "${status}" --arg message "${message}" --argjson m "${movement_id:-null}" \
    '{id: $id, event: "ark_send", "label": $lbl, destination: $d, amount_sat: $a, status: $status, movementId: $m, message: $message}'
}

# ark_match_send <history json> <destination> <amount> <floor> [taken ids json]
# Oldest successful movement after the floor that paid amount to destination
# and is not already recorded for another send.
ark_match_send() {
  printf '%s' "${1}" | jq -r --arg d "${2}" --argjson a "${3}" --argjson f "${4:-0}" --argjson t "${5:-[]}" '
    [ .[] | select(.status == "successful" and .id > $f and ([.id] | inside($t) | not))
      | select(any(.sent_to[]; .destination.type == "ark" and .destination.value == $d and .amount_sat == $a)) ]
    | sort_by(.id) | first | .id // empty'
}

# ark_record_send_movement <send id> <destination> <amount> <floor>
# Records the matching movement on the send and prints its id. A movement
# already recorded for another send is skipped. Callers hold ./.ark_send.lock.
ark_record_send_movement() {
  local history taken movement_id
  history=$(barkd_call GET "/history?type=ark&value=${2}") || return 1
  taken=$(sql "SELECT COALESCE(json_agg(movement_id), '[]') FROM ark_send WHERE destination='${2}' AND movement_id IS NOT NULL AND id <> ${1}")
  movement_id=$(ark_match_send "${history}" "${2}" "${3}" "${4}" "${taken:-[]}")
  [ -n "${movement_id}" ] || return 0
  sql "UPDATE ark_send SET movement_id=${movement_id} WHERE id=${1}" > /dev/null
  printf '%s' "${movement_id}"
}

# ark_claim_send_movement: ark_record_send_movement under the send lock.
ark_claim_send_movement() {
  (
  flock --timeout 60 9 || exit 1
  ark_record_send_movement "$@"
  ) 9>./.ark_send.lock
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

ark_getsend() {
  trace "Entering ark_getsend(${1})..."

  local row
  row=$(sql_json "SELECT id, label, destination, amount_sat, status, movement_id, error FROM ark_send WHERE label='$(sql_quote "${1}")'")
  if [ -z "${row}" ]; then
    echo '{"error":{"code":-32602,"message":"send not found"}}'
    return 1
  fi
  printf '%s' "${row}" | jq -c '
    {id: .id, event: "ark_send", "label": .label, destination: .destination, amount_sat: .amount_sat,
     status: .status, movementId: .movement_id, error: .error}'
}
