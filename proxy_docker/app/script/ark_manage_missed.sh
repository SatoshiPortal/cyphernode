#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./ark_callbacks.sh

# Runs from proxycron. Re-reads barkd's history so nothing is lost when the
# proxy was down or the notification stream lagged, then posts pending
# callbacks.
#
# The history floor is the highest movement id below which every movement is
# final. Above the floor, a movement is processed once when it is first seen
# final: either its id is above the highest id seen so far, or it was still
# pending at the previous run. A movement that stays pending therefore holds
# the floor without making every later run replay the movements after it.
#
# One run at a time: proxycron, the notification stream and the request
# handler can all start it, and a run can outlast the cron interval.
ark_manage_missed() {
  trace "Entering ark_manage_missed()..."
  (
  local history floor seen pending new_floor new_seen new_pending movements movement

  if ! flock --nonblock 7; then
    trace "[ark_manage_missed] a run is already in progress"
    exit 0
  fi

  # Unpaid Lightning invoices past their expiry get no callback.
  sql "UPDATE ark_ln_invoice SET status='expired' WHERE status='unpaid' AND expires_at IS NOT NULL AND expires_at < EXTRACT(EPOCH FROM NOW())" > /dev/null

  history=$(barkd_call GET /history)
  if [ "$?" -ne 0 ]; then
    trace "[ark_manage_missed] barkd history unavailable"
    ark_do_callbacks
    exit 0
  fi

  floor=$(sql "SELECT value FROM cyphernode_props WHERE property='ark_history_floor'")
  floor=${floor:-0}
  seen=$(sql "SELECT value FROM cyphernode_props WHERE property='ark_history_seen'")
  seen=${seen:-${floor}}
  pending=$(sql "SELECT value FROM cyphernode_props WHERE property='ark_history_pending'")
  pending=${pending:-[]}

  movements=$(printf '%s' "${history}" | jq -c --argjson f "${floor}" --argjson s "${seen}" --argjson p "${pending}" '
    .[] | select((.status == "successful" or .status == "failed") and .id > $f)
    | select(.id > $s or (.id as $i | $p | any(.[]; . == $i)))')
  local IFS="
"
  for movement in ${movements}; do
    ark_process_movement "${movement}"
  done
  unset IFS

  new_floor=$(printf '%s' "${history}" | jq --argjson f "${floor}" '
    ([.[] | select(.status == "pending") | .id] | min) as $p
    | (if $p then $p - 1 else ([.[].id] | max // 0) end) | if . > $f then . else $f end')
  new_seen=$(printf '%s' "${history}" | jq --argjson s "${seen}" '[.[].id] | max // 0 | if . > $s then . else $s end')
  new_pending=$(printf '%s' "${history}" | jq -c '[.[] | select(.status == "pending") | .id]')
  [ "${new_floor}" != "${floor}" ] && ark_history_prop_set ark_history_floor "${new_floor}"
  [ "${new_seen}" != "${seen}" ] && ark_history_prop_set ark_history_seen "${new_seen}"
  [ "${new_pending}" != "${pending}" ] && ark_history_prop_set ark_history_pending "${new_pending}"

  ark_do_callbacks
  ) 7>./.arkmanagemissed.lock
  return 0
}

ark_history_prop_set() {
  sql "UPDATE cyphernode_props SET value='${2}' WHERE property='${1}'" > /dev/null
  sql "INSERT INTO cyphernode_props (property, value, category) SELECT '${1}', '${2}', 'ark' WHERE NOT EXISTS (SELECT 1 FROM cyphernode_props WHERE property='${1}')" > /dev/null
}
