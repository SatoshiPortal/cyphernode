#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./elements_importaddress.sh
. ./elements_confirmation.sh

elements_manage_not_imported() {
  # When we tried to import watched addresses in the watching node,
  # if it didn't succeed, we try again here.

  trace "[Entering elements_manage_not_imported()]"

  local watches=$(sql 'SELECT address FROM elements_watching WHERE watching AND NOT imported')
  trace "[elements_manage_not_imported] watches=${watches}"

  local result
  local returncode
  local IFS=$'\n'
  for address in ${watches}
  do
    result=$(elements_importaddress_rpc "${address}")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      sql "UPDATE elements_watching SET imported=1 WHERE address=\"${address}\""
    fi
  done

  return 0
}

elements_manage_missed_conf() {
  # Maybe we missed confirmations, because we were down or no network or
  # whatever, so we look at what might be missed and do confirmations.

  trace "[Entering elements_manage_missed_conf()]"

  local watches=$(sql 'SELECT address FROM elements_watching w LEFT JOIN elements_watching_tx ON w.id = watching_id LEFT JOIN elements_tx t ON t.id = tx_id WHERE watching AND imported AND (tx_id IS NULL OR t.confirmations=0)')
  trace "[elements_manage_missed_conf] watches=${watches}"
  if [ ${#watches} -eq 0 ]; then
    trace "[elements_manage_missed_conf] Nothing missed!"
    return 0
  fi

  local addresses
  local data
  local result
  local returncode
  local IFS=$'\n'
  for address in ${watches}
  do
    if [ -z ${addresses} ]; then
      addresses="[\"${address}\""
    else
      addresses="${addresses},\"${address}\""
    fi
  done
  addresses="${addresses}]"

  # Watching addresses with UTXO are transactions being watched that went through without us knowing it, we missed the conf
  data="{\"method\":\"listunspent\",\"params\":[0, 9999999, ${addresses}]}"
  local unspents
  unspents=$(send_to_elements_watcher_node ${data})
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne 0 ]; then
    return ${returncode}
  fi

  local txids=$(echo "${unspents}" | jq -r ".result[].txid")
  for txid in ${txids}
  do
    elements_confirmation "${txid}"
  done

  return 0

}
