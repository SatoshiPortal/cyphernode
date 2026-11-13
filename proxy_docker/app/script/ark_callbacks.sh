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
  local status movement_id received jobs job_status job_error
  local address amount watches watch_id vtxos

  status=$(printf '%s' "${movement}" | jq -r '.status')
  movement_id=$(printf '%s' "${movement}" | jq -r '.id')
  trace "[ark_process_movement] movement ${movement_id} status ${status}"

  # Lightning movements carry their payment hash in the metadata; a failed
  # send is an outcome too.
  case "$(printf '%s' "${movement}" | jq -r '.subsystem.name // empty')" in
    bark.lightning_send)
      case "${status}" in
        successful) ark_ln_send_finish "$(printf '%s' "${movement}" | jq -r '.metadata.payment_hash // empty')" complete "${movement_id}" ;;
        failed) ark_ln_send_finish "$(printf '%s' "${movement}" | jq -r '.metadata.payment_hash // empty')" failed "${movement_id}" ;;
      esac
      return 0
      ;;
    bark.lightning_receive)
      [ "${status}" = "successful" ] && ark_ln_receive_movement "${movement}"
      return 0
      ;;
    bark.arkoor)
      # An invoice settled on its Ark address has no Lightning payment hash
      # in the movement. Resolve the pre-submission row by invoice instead.
      local invoice hash
      invoice=$(printf '%s' "${movement}" | jq -r '.sent_to[]? | select(.destination.type == "invoice") | .destination.value' | head -n 1)
      if [ -n "${invoice}" ]; then
        hash=$(sql "SELECT payment_hash FROM ark_ln_send WHERE destination='$(sql_quote "${invoice}")' AND NOT published ORDER BY id DESC LIMIT 1")
        case "${status}" in
          successful) ark_ln_send_finish "${hash}" complete "${movement_id}" ;;
          failed) ark_ln_send_finish "${hash}" failed "${movement_id}" ;;
        esac
        return 0
      fi
      ;;
  esac

  case "${status}" in
    successful) job_status=successful; job_error=NULL ;;
    failed) job_status=failed; job_error="'Ark movement failed'" ;;
    *) return 0 ;;
  esac

  vtxos=$(printf '%s' "${movement}" | jq -c '.output_vtxos // []')

  if [ "${status}" = "successful" ]; then
    # Receives: one row per (movement, watch)
    received=$(printf '%s' "${movement}" | jq -r '.received_on[]? | select(.destination.type == "ark") | "\(.destination.value)|\(.amount_sat)"')
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
  fi

  # Jobs: offboards are matched by movement id, boards by their VTXO ids
  sql "UPDATE ark_job SET status='${job_status}', error=${job_error}, movement_id=${movement_id} WHERE status='pending' AND movement_id=${movement_id}" > /dev/null
  jobs=$(sql "SELECT id, vtxos FROM ark_job WHERE status='pending' AND kind='board' AND movement_id IS NULL")
  local IFS="
"
  for line in ${jobs}; do
    local job_id job_vtxos overlap
    job_id=$(printf '%s' "${line}" | cut -d '|' -f1)
    job_vtxos=$(printf '%s' "${line}" | cut -d '|' -f2-)
    overlap=$(jq -cn --argjson a "${job_vtxos:-[]}" --argjson b "${vtxos}" '($a - ($a - $b)) | length')
    if [ "${overlap}" -gt 0 ]; then
      sql "UPDATE ark_job SET status='${job_status}', error=${job_error}, movement_id=${movement_id} WHERE id=${job_id} AND status='pending'" > /dev/null
    fi
  done
  unset IFS

  return 0
}

# ark_ln_receive_movement <movement json>
# The invoice amount is in received_on; what the wallet keeps after the
# server's fee is the effective balance.
ark_ln_receive_movement() {
  trace "Entering ark_ln_receive_movement()..."

  local movement_id payment_hash received fee

  movement_id=$(printf '%s' "${1}" | jq -r '.id')
  payment_hash=$(printf '%s' "${1}" | jq -r '.metadata.payment_hash // empty')
  received=$(printf '%s' "${1}" | jq -r '.effective_balance_sat // 0')
  fee=$(printf '%s' "${1}" | jq -r '.offchain_fee_sat // 0')
  [ -n "${payment_hash}" ] || return 0

  sql "UPDATE ark_ln_invoice SET status='paid', movement_id=${movement_id}, received_sat=${received}, fee_sat=${fee}"\
" WHERE payment_hash='$(sql_quote "${payment_hash}")' AND status <> 'paid'" > /dev/null
}

# Posts every callback not yet delivered. The lock keeps the notification
# stream and proxycron from posting the same callback twice.
ark_do_callbacks() {
  trace "Entering ark_do_callbacks()..."
  (
  local rows row
  local IFS="
"

  if ! flock --timeout 60 8; then
    trace "[ark_do_callbacks] could not get the lock"
    exit 1
  fi

  rows=$(sql_json "SELECT r.id, w.callback_url, w.label, w.event_message, r.address, r.amount_sat, r.movement_id, r.vtxos, w.expected_amount_sat"\
" FROM ark_receive r JOIN ark_watching w ON w.id = r.ark_watching_id"\
" WHERE NOT r.calledback AND w.callback_url IS NOT NULL AND w.callback_url <> ''")
  for row in ${rows}; do
    ark_receive_callback "${row}"
  done

  rows=$(sql_json "SELECT id, kind, label, callback_url, txid, movement_id, vtxos, status, error FROM ark_job"\
" WHERE NOT calledback AND status <> 'pending' AND callback_url IS NOT NULL AND callback_url <> ''")
  for row in ${rows}; do
    ark_job_callback "${row}"
  done

  rows=$(sql_json "SELECT id, label, bolt11, payment_hash, callback_url, event_message, amount_sat, received_sat, fee_sat, movement_id FROM ark_ln_invoice"\
" WHERE NOT calledback AND status = 'paid' AND callback_url IS NOT NULL AND callback_url <> ''")
  for row in ${rows}; do
    ark_ln_invoice_callback "${row}"
  done

  # Receives, jobs and invoices without a callback URL are marked delivered immediately.
  sql "UPDATE ark_receive r SET calledback=true FROM ark_watching w WHERE w.id = r.ark_watching_id AND NOT r.calledback AND (w.callback_url IS NULL OR w.callback_url = '')" > /dev/null
  sql "UPDATE ark_job SET calledback=true WHERE NOT calledback AND status <> 'pending' AND (callback_url IS NULL OR callback_url = '')" > /dev/null
  sql "UPDATE ark_ln_invoice SET calledback=true WHERE NOT calledback AND status = 'paid' AND (callback_url IS NULL OR callback_url = '')" > /dev/null
  ) 8>./.ark_callbacks.lock

  return 0
}

# ark_receive_callback <json row>
ark_receive_callback() {
  trace "Entering ark_receive_callback()..."

  local row=${1}
  local id url data returncode

  id=$(printf '%s' "${row}" | jq -r '.id')
  url=$(printf '%s' "${row}" | jq -r '.callback_url')
  data=$(printf '%s' "${row}" | jq -c '
    {id: .id, event: "ark_receive", address: .address, "label": .label, eventMessage: .event_message,
     amount_sat: .amount_sat, expectedAmount: .expected_amount_sat, movementId: .movement_id,
     vtxos: (.vtxos | fromjson? // [])}')
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

# ark_job_callback <json row>
ark_job_callback() {
  trace "Entering ark_job_callback()..."

  local row=${1}
  local id url data returncode

  id=$(printf '%s' "${row}" | jq -r '.id')
  url=$(printf '%s' "${row}" | jq -r '.callback_url')
  data=$(printf '%s' "${row}" | jq -c '
    {id: .id, event: ("ark_" + .kind), "label": .label, status: .status, txid: .txid,
     movementId: .movement_id, vtxos: (.vtxos | fromjson? // []), error: .error}')
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

# ark_ln_invoice_callback <json row>
ark_ln_invoice_callback() {
  trace "Entering ark_ln_invoice_callback()..."

  local row=${1}
  local id url data returncode

  id=$(printf '%s' "${row}" | jq -r '.id')
  url=$(printf '%s' "${row}" | jq -r '.callback_url')
  data=$(printf '%s' "${row}" | jq -c '
    {id: .id, event: "ark_lnreceive", "label": .label, bolt11: .bolt11, payment_hash: .payment_hash,
     eventMessage: .event_message, msatoshi: (.amount_sat * 1000),
     amount_received_msat: (if .received_sat then .received_sat * 1000 else null end),
     fee_sat: .fee_sat, movementId: .movement_id}')
  trace "[ark_ln_invoice_callback] data=${data}"

  notify_web "${url}" "${data}" "${TOR_ADDR_WATCH_WEBHOOKS}" > /dev/null
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    sql "UPDATE ark_ln_invoice SET calledback=true, calledback_ts=CURRENT_TIMESTAMP WHERE id=${id}" > /dev/null
  else
    trace "[ark_ln_invoice_callback] callback failed: ${url}"
    sql "UPDATE ark_ln_invoice SET callback_failures=callback_failures+1 WHERE id=${id}" > /dev/null
  fi
  return ${returncode}
}
