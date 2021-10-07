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

  # The strategy here: get the list of watched addresses, see if they received something on the Bitcoin node,
  # and for each ones that received something after the watching timestamp, we kinda missed them...

  trace "[Entering manage_missed_conf()]"

  local watches=$(sql 'SELECT DISTINCT address FROM watching w LEFT JOIN watching_tx ON w.id = watching_id LEFT JOIN tx t ON t.id = tx_id WHERE watching AND imported AND (tx_id IS NULL OR t.confirmations=0) ORDER BY address')
  trace "[manage_missed_conf] watches=${watches}"
  if [ ${#watches} -eq 0 ]; then
    trace "[manage_missed_conf] Nothing missed!"
    return 0
  fi

  local received
  local received_addresses
  local received_watches

  data='{"method":"listreceivedbyaddress","params":[0,false,true]}'
  received=$(send_to_watcher_node "${data}")
  received_addresses=$(echo "${received}" | jq -r ".result[].address" | sort)
  trace "[manage_missed_conf] received_addresses=${received_addresses}"

  # Let's extract addresses that are in the watches list as well as in the received_addresses list
  echo "${watches}" > watches-$$
  echo "${received_addresses}" > received_addresses-$$
  received_watches=$(comm -12 watches-$$ received_addresses-$$)
  trace "[manage_missed_conf] received_watches=${received_watches}"
  rm watches-$$ received_addresses-$$

  local received
  local received_address
  local watching
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
  for address in ${received_watches}
  do
    watching=$(sql 'SELECT address, inserted_ts FROM watching WHERE address="'${address}'"')
    trace "[manage_missed_conf] watching=${watching}"
    if [ ${#watching} -eq 0 ]; then
      trace "[manage_missed_conf] Nothing missed!"
      continue
    fi

    # Let's get confirmed received txs for the address
    # address=$(echo "${watches}" | cut -d '|' -f1)
    inserted_ts=$(date -d "$(echo "${watching}" | cut -d '|' -f2)" +"%s")
    trace "[manage_missed_conf] inserted_ts=${inserted_ts}"

    received_address=$(echo "${received}" | jq -Mc ".result | map(select(.address==\"${address}\" and .confirmations>0))[0]")
    trace "[manage_missed_conf] received_address=${received_address}"
    if [ "${received_address}" = "null" ]; then
      # Not confirmed while we were away...
      trace "[manage_missed_conf] Nothing missed here"
    else
      # We got something confirmed
      # Let's find out if it was confirmed after being watched
      trace "[manage_missed_conf] We got something confirmed"
      latesttxid=$(echo "${received_address}" | jq -r ".txids | last")
      trace "[manage_missed_conf] latesttxid=${latesttxid}"
      data='{"method":"gettransaction","params":["'${latesttxid}'"]}'
      tx=$(send_to_watcher_node ${data})
      blocktime=$(echo "${tx}" | jq '.result.blocktime')
      txtime=$(echo "${tx}" | jq '.result.time')
      confirmations=$(echo "${tx}" | jq '.result.confirmations')

      trace "[manage_missed_conf] blocktime=${blocktime}"
      trace "[manage_missed_conf] txtime=${txtime}"
      trace "[manage_missed_conf] inserted_ts=${inserted_ts}"
      trace "[manage_missed_conf] confirmations=${confirmations}"

      if [ "${txtime}" -gt "${inserted_ts}" ] && [ "${confirmations}" -gt "0" ]; then
        # Mined after watch, we missed it!
        trace "[manage_missed_conf] Mined after watch, we missed it!"
        confirmation "${latesttxid}" "true"
      fi
    fi
  done

  return 0
}

case "${0}" in *manage_missed_conf.sh) manage_not_imported $@; manage_missed_conf $@;; esac
