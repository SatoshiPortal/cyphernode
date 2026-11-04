#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./ark_callbacks.sh

# Runs from proxycron. Re-reads barkd's history so nothing is lost when the
# proxy was down or the notification stream lagged, reconciles sends whose
# outcome was unknown, then posts pending callbacks.
ark_manage_missed() {
  trace "Entering ark_manage_missed()..."

  local history movements movement
  local sends row id destination amount movement_id

  history=$(barkd_call GET /history)
  if [ "$?" -ne 0 ]; then
    trace "[ark_manage_missed] barkd history unavailable"
    ark_do_callbacks
    return 0
  fi

  movements=$(printf '%s' "${history}" | jq -c '.[] | select(.status == "successful")')
  local IFS="
"
  for movement in ${movements}; do
    ark_process_movement "${movement}"
  done
  unset IFS

  sends=$(sql "SELECT id, destination, amount_sat FROM ark_send WHERE status='unknown'")
  local IFS="
"
  for row in ${sends}; do
    id=$(printf '%s' "${row}" | cut -d '|' -f1)
    destination=$(printf '%s' "${row}" | cut -d '|' -f2)
    amount=$(printf '%s' "${row}" | cut -d '|' -f3)
    movement_id=$(printf '%s' "${history}" | jq -r --arg d "${destination}" --argjson a "${amount}" '
      [ .[] | select(.status == "successful")
        | select(any(.sent_to[]; .destination.type == "ark" and .destination.value == $d and .amount_sat == $a)) ]
      | sort_by(.id) | last | .id // empty')
    if [ -n "${movement_id}" ]; then
      trace "[ark_manage_missed] send ${id} reconciled to movement ${movement_id}"
      sql "UPDATE ark_send SET status='successful', movement_id=${movement_id} WHERE id=${id} AND status='unknown'" > /dev/null
    fi
  done
  unset IFS

  ark_do_callbacks
  return 0
}
