#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./importaddress.sh
. ./confirmation.sh

manage_not_imported() {
  # When we tried to import watched addresses in the watching node,
  # if it didn't succeed, we try again here.

  trace "[Entering manage_not_imported()]"

  local watches=$(sql 'SELECT address, label FROM watching WHERE watching AND NOT imported')
  trace "[manage_not_imported] watches=${watches}"

  local result
  local returncode
  local IFS=$'\n'
  for row in ${watches}
  do
    address=$(echo "${row}" | cut -d '|' -f1)
    label=$(echo "${row}" | cut -d '|' -f2)
    result=$(importaddress_rpc "${address}" "${label}")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      sql "UPDATE watching SET imported=1 WHERE address=\"${address}\""
    fi
  done

  return 0
}

manage_missed_conf() {
  # Maybe we missed confirmations, because we were down or no network or
  # whatever, so we look at what might be missed and do confirmations.

  trace "[Entering manage_missed_conf()]"

  local watches=$(sql 'SELECT DISTINCT address, w.inserted_ts FROM watching w LEFT JOIN watching_tx ON w.id = watching_id LEFT JOIN tx t ON t.id = tx_id WHERE watching AND imported AND (tx_id IS NULL OR t.confirmations=0)')
  trace "[manage_missed_conf] watches=${watches}"
  if [ ${#watches} -eq 0 ]; then
    trace "[manage_missed_conf] Nothing missed!"
    return 0
  fi

  local received
  local latesttxid
  local tx
  local blocktime
  local data
  local result
  local returncode
  local row
  local address
  local inserted_ts
  local txid
  local txids
  local IFS=$'\n'
  for row in ${watches}
  do
    # Let's get confirmed received txs for the address
    address=$(echo "${row}" | cut -d '|' -f1)
    inserted_ts=$(date -d "$(echo "${row}" | cut -d '|' -f2)" +"%s")
    trace "[manage_missed_conf] address=${address}"

    data='{"method":"listreceivedbyaddress","params":[0, false, true, "'${address}'"]}'
    received=$(send_to_watcher_node ${data} | jq '.result[0]')
    if [ "${received}" = "null" ]; then
      # Not confirmed while we were away...
      trace "[manage_missed_conf] Nothing missed here"
    else
      # We got something confirmed
      # Let's find out if it was confirmed after being watched
      trace "[manage_missed_conf] We got something confirmed"
      latesttxid=$(echo "${received}" | jq -r ".txids | last")
      data='{"method":"gettransaction","params":["'${latesttxid}'"]}'
      tx=$(send_to_watcher_node ${data})
      blocktime=$(echo "${tx}" | jq '.result.blocktime')
      txtime=$(echo "${tx}" | jq '.result.time')
      confirmations=$(echo "${tx}" | jq '.result.confirmations')

      trace "[manage_missed_conf] blocktime=${blocktime}"
      trace "[manage_missed_conf] txtime=${txtime}"
      trace "[manage_missed_conf] inserted_ts=${inserted_ts}"
      trace "[manage_missed_conf] confirmations=${confirmations}"

      if [ "${txtime}" -gt "${inserted_ts}" ]; then
        # Mined after watch, we missed it!
        trace "[manage_missed_conf] Mined after watch, we missed it!"
        confirmation "${latesttxid}" "true"
      fi
    fi
  done

  return 0
}

case "${0}" in *manage_missed_conf.sh) manage_not_imported $@; manage_missed_conf $@;; esac
