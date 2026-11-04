#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./ark_callbacks.sh

# Runs from proxycron. Re-reads barkd's history so nothing is lost when the
# proxy was down or the notification stream lagged, reconciles sends whose
# outcome is unknown, then posts pending callbacks.
#
# The history floor is the highest movement id below which every movement is
# final, so each run only processes what is new or was still pending.
ark_manage_missed() {
  trace "Entering ark_manage_missed()..."

  local history floor new_floor movements movement
  local sends row id destination amount send_floor status movement_id

  history=$(barkd_call GET /history)
  if [ "$?" -ne 0 ]; then
    trace "[ark_manage_missed] barkd history unavailable"
    ark_do_callbacks
    return 0
  fi

  floor=$(sql "SELECT value FROM cyphernode_props WHERE property='ark_history_floor'")
  floor=${floor:-0}
  movements=$(printf '%s' "${history}" | jq -c --argjson f "${floor}" '.[] | select(.status == "successful" and .id > $f)')
  local IFS="
"
  for movement in ${movements}; do
    ark_process_movement "${movement}"
  done
  unset IFS

  new_floor=$(printf '%s' "${history}" | jq --argjson f "${floor}" '
    ([.[] | select(.status == "pending") | .id] | min) as $p
    | (if $p then $p - 1 else ([.[].id] | max // 0) end) | if . > $f then . else $f end')
  [ "${new_floor}" != "${floor}" ] && sql "UPDATE cyphernode_props SET value='${new_floor}' WHERE property='ark_history_floor'" > /dev/null

  # Sends whose outcome barkd never reported, and sends left pending by a
  # proxy restart, are matched against the movements made after them.
  sends=$(sql_json "SELECT id, destination, amount_sat, movement_floor, status FROM ark_send"\
" WHERE status='unknown' OR (status='pending' AND inserted_ts < CURRENT_TIMESTAMP - INTERVAL '10 minutes')")
  local IFS="
"
  for row in ${sends}; do
    id=$(printf '%s' "${row}" | jq -r '.id')
    destination=$(printf '%s' "${row}" | jq -r '.destination')
    amount=$(printf '%s' "${row}" | jq -r '.amount_sat')
    send_floor=$(printf '%s' "${row}" | jq -r '.movement_floor')
    status=$(printf '%s' "${row}" | jq -r '.status')
    movement_id=$(ark_match_send "${history}" "${destination}" "${amount}" "${send_floor}")
    if [ -n "${movement_id}" ]; then
      trace "[ark_manage_missed] send ${id} reconciled to movement ${movement_id}"
      sql "UPDATE ark_send SET status='successful', movement_id=${movement_id} WHERE id=${id} AND status='${status}'" > /dev/null
    elif [ "${status}" = "pending" ]; then
      trace "[ark_manage_missed] send ${id} stale, now unknown"
      sql "UPDATE ark_send SET status='unknown' WHERE id=${id} AND status='pending'" > /dev/null
    fi
  done
  unset IFS

  ark_do_callbacks
  return 0
}
