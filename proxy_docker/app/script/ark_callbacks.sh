#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./notify.sh
. ./ark.sh

# Turns barkd movements into Cyphernode callbacks.
#
# ark_process_movement is idempotent: a received movement is recorded once per
# watch (ON CONFLICT DO NOTHING) and a job is completed once. Callbacks are
# posted through the notifier and retried by ark_do_callbacks until they
# succeed.

# ark_process_movement <movement json>
ark_process_movement() {
  trace "Entering ark_process_movement()..."

  local movement=${1}
  local status movement_id received jobs
  local address amount watches watch_id vtxos

  status=$(printf '%s' "${movement}" | jq -r '.status')
  movement_id=$(printf '%s' "${movement}" | jq -r '.id')
  trace "[ark_process_movement] movement ${movement_id} status ${status}"

  [ "${status}" = "successful" ] || return 0

  vtxos=$(printf '%s' "${movement}" | jq -c '.output_vtxos // []')

  # Receives: one row per (movement, watch)
  received=$(printf '%s' "${movement}" | jq -r '.received_on[] | select(.destination.type == "ark") | "\(.destination.value)|\(.amount_sat)"')
  local IFS="
"
  for line in ${received}; do
    address=$(printf '%s' "${line}" | cut -d '|' -f1)
    amount=$(printf '%s' "${line}" | cut -d '|' -f2)
    watches=$(sql "SELECT id FROM ark_watching WHERE watching AND address='${address}'")
    for watch_id in ${watches}; do
      sql "INSERT INTO ark_receive (movement_id, ark_watching_id, address, amount_sat, vtxos)"\
" VALUES (${movement_id}, ${watch_id}, '${address}', ${amount}, '$(sql_quote "${vtxos}")')"\
" ON CONFLICT (movement_id, ark_watching_id) DO NOTHING" > /dev/null
    done
  done
  unset IFS

  # Jobs: offboards are matched by movement id, boards by their VTXO ids
  sql "UPDATE ark_job SET status='successful', movement_id=${movement_id} WHERE status='pending' AND movement_id=${movement_id}" > /dev/null
  jobs=$(sql "SELECT id, vtxos FROM ark_job WHERE status='pending' AND kind='board' AND movement_id IS NULL")
  local IFS="
"
  for line in ${jobs}; do
    local job_id job_vtxos overlap
    job_id=$(printf '%s' "${line}" | cut -d '|' -f1)
    job_vtxos=$(printf '%s' "${line}" | cut -d '|' -f2-)
    overlap=$(jq -cn --argjson a "${job_vtxos:-[]}" --argjson b "${vtxos}" '($a - ($a - $b)) | length')
    if [ "${overlap}" -gt 0 ]; then
      sql "UPDATE ark_job SET status='successful', movement_id=${movement_id} WHERE id=${job_id}" > /dev/null
    fi
  done
  unset IFS

  return 0
}

# Posts every callback not yet delivered.
ark_do_callbacks() {
  trace "Entering ark_do_callbacks()..."

  local rows row
  local IFS="
"

  rows=$(sql "SELECT r.id, w.callback_url, w.label, w.event_message, r.address, r.amount_sat, r.movement_id, r.vtxos, w.expected_amount_sat"\
" FROM ark_receive r JOIN ark_watching w ON w.id = r.ark_watching_id"\
" WHERE NOT r.calledback AND w.callback_url IS NOT NULL AND w.callback_url <> ''")
  for row in ${rows}; do
    ark_receive_callback "${row}"
  done

  rows=$(sql "SELECT id, kind, label, callback_url, txid, movement_id, vtxos, status FROM ark_job"\
" WHERE NOT calledback AND status <> 'pending' AND callback_url IS NOT NULL AND callback_url <> ''")
  for row in ${rows}; do
    ark_job_callback "${row}"
  done

  # Receives and jobs without a callback URL are marked delivered immediately.
  sql "UPDATE ark_receive r SET calledback=true FROM ark_watching w WHERE w.id = r.ark_watching_id AND NOT r.calledback AND (w.callback_url IS NULL OR w.callback_url = '')" > /dev/null
  sql "UPDATE ark_job SET calledback=true WHERE NOT calledback AND status <> 'pending' AND (callback_url IS NULL OR callback_url = '')" > /dev/null

  return 0
}

ark_receive_callback() {
  trace "Entering ark_receive_callback()..."

  local row=${1}
  local id url label event_message address amount movement_id vtxos expected data returncode

  id=$(printf '%s' "${row}" | cut -d '|' -f1)
  url=$(printf '%s' "${row}" | cut -d '|' -f2)
  label=$(printf '%s' "${row}" | cut -d '|' -f3)
  event_message=$(printf '%s' "${row}" | cut -d '|' -f4)
  address=$(printf '%s' "${row}" | cut -d '|' -f5)
  amount=$(printf '%s' "${row}" | cut -d '|' -f6)
  movement_id=$(printf '%s' "${row}" | cut -d '|' -f7)
  vtxos=$(printf '%s' "${row}" | cut -d '|' -f8)
  expected=$(printf '%s' "${row}" | cut -d '|' -f9)

  data=$(jq -cn --argjson id "${id}" --arg label "${label}" --arg em "${event_message}" --arg a "${address}" \
    --argjson amount "${amount}" --argjson m "${movement_id}" --argjson vtxos "${vtxos:-[]}" --arg expected "${expected}" \
    '{id: $id, event: "ark_receive", address: $a,
      label: (if $label == "" then null else $label end),
      eventMessage: (if $em == "" then null else $em end),
      amount_sat: $amount, expectedAmount: (if $expected == "" then null else ($expected | tonumber) end),
      movementId: $m, vtxos: $vtxos}')
  trace "[ark_receive_callback] data=${data}"

  notify_web "${url}" "${data}" "${TOR_ADDR_WATCH_WEBHOOKS}" > /dev/null
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    sql "UPDATE ark_receive SET calledback=true, calledback_ts=CURRENT_TIMESTAMP WHERE id=${id}" > /dev/null
  else
    trace "[ark_receive_callback] callback failed: ${url}"
    sql "UPDATE ark_receive SET callback_failures=callback_failures+1 WHERE id=${id}" > /dev/null
  fi
  return ${returncode}
}

ark_job_callback() {
  trace "Entering ark_job_callback()..."

  local row=${1}
  local id kind label url txid movement_id vtxos status data returncode

  id=$(printf '%s' "${row}" | cut -d '|' -f1)
  kind=$(printf '%s' "${row}" | cut -d '|' -f2)
  label=$(printf '%s' "${row}" | cut -d '|' -f3)
  url=$(printf '%s' "${row}" | cut -d '|' -f4)
  txid=$(printf '%s' "${row}" | cut -d '|' -f5)
  movement_id=$(printf '%s' "${row}" | cut -d '|' -f6)
  vtxos=$(printf '%s' "${row}" | cut -d '|' -f7)
  status=$(printf '%s' "${row}" | cut -d '|' -f8)

  data=$(jq -cn --argjson id "${id}" --arg kind "${kind}" --arg label "${label}" --arg txid "${txid}" \
    --argjson m "${movement_id:-null}" --argjson vtxos "${vtxos:-[]}" --arg status "${status}" \
    '{id: $id, event: ("ark_" + $kind), label: $label, status: $status, txid: $txid, movementId: $m, vtxos: $vtxos}')
  trace "[ark_job_callback] data=${data}"

  notify_web "${url}" "${data}" "${TOR_TXID_WATCH_WEBHOOKS}" > /dev/null
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    sql "UPDATE ark_job SET calledback=true, calledback_ts=CURRENT_TIMESTAMP WHERE id=${id}" > /dev/null
  else
    trace "[ark_job_callback] callback failed: ${url}"
    sql "UPDATE ark_job SET callback_failures=callback_failures+1 WHERE id=${id}" > /dev/null
  fi
  return ${returncode}
}
