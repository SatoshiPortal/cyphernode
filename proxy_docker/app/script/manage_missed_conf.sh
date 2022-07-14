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
  local IFS="
"
  for row in ${watches}
  do
    address=$(echo "${row}" | cut -d '|' -f1)
    label=$(echo "${row}" | cut -d '|' -f2)
    result=$(importaddress_rpc "${address}" "${label}")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      sql "UPDATE watching SET imported=true WHERE address='${address}'"
    fi
  done

  return 0
}

manage_missed_conf() {
  # Maybe we missed 0-conf or 1-conf watched txs, because we were down or no network or
  # whatever, so we look at what might be missed and do confirmations.

  # The strategy here: get the list of watched addresses, see if they received something on the Bitcoin node,
  # and for each ones that received something after the watching timestamp, we kinda missed them...

  trace "[Entering manage_missed_conf()]"

  local watches=$(sql "SELECT DISTINCT address FROM watching w LEFT JOIN watching_tx ON w.id = watching_id LEFT JOIN tx t ON t.id = tx_id WHERE watching AND imported ORDER BY address")
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
  local confirmations
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
  local calledback0conf
  local txid
  local txids
  local IFS="
"
  for address in ${received_watches}
  do
    watching=$(sql "SELECT address, inserted_ts, calledback0conf FROM watching WHERE address='${address}'")
    trace "[manage_missed_conf] watching=${watching}"
    if [ ${#watching} -eq 0 ]; then
      trace "[manage_missed_conf] Nothing missed!"
      continue
    fi

    inserted_ts=$(date -d "$(echo "${watching}" | cut -d '|' -f2)" +%s)
    trace "[manage_missed_conf] inserted_ts=${inserted_ts}"
    calledback0conf=$(echo "${watching}" | cut -d '|' -f3)
    trace "[manage_missed_conf] calledback0conf=${calledback0conf}"

    received_address=$(echo "${received}" | jq -Mc ".result | map(select(.address==\"${address}\"))[0]")
    trace "[manage_missed_conf] received_address=${received_address}"
    confirmations=$(echo "${received_address}" | jq -r ".confirmations")
    trace "[manage_missed_conf] confirmations=${confirmations}"

    if [ "${confirmations}" -eq "0" ] && [ "${calledback0conf}" = "t" ]; then
      # 0-conf and calledback0conf is true, so let's skip this one
      trace "[manage_missed_conf] Nothing missed!"
    else
      # 0-conf and calledback0conf false, let's call confirmation
      # or
      # 1-conf and calledback1conf false, let's call confirmation
      trace "[manage_missed_conf] We got something to check..."

      latesttxid=$(echo "${received_address}" | jq -r ".txids | last")
      data="{\"method\":\"gettransaction\",\"params\":[\"${latesttxid}\",true,true]}"
      trace "[manage_missed_conf] calling method=${data}"

      tx=$(send_to_watcher_node "${data}")

      blocktime=$(echo "${tx}" | jq '.result.blocktime')
      txtime=$(echo "${tx}" | jq '.result.time')

      trace "[manage_missed_conf] blocktime=${blocktime}"
      trace "[manage_missed_conf] txtime=${txtime}"
      trace "[manage_missed_conf] inserted_ts=${inserted_ts}"
      trace "[manage_missed_conf] confirmations=${confirmations}"

      if [ "${txtime}" -ge "${inserted_ts}" ]; then
        # Broadcast or mined after watch, we missed it!
        trace "[manage_missed_conf] Broadcast or mined after watch, we missed it!"
        # We skip the callbacks because do_callbacks is called right after in
        # requesthandler.executecallbacks (where we're from)
        confirmation "$(echo "${tx}" | jq -Mc '.result' | base64 -w 0)" "true"
      fi
    fi
  done

  return 0
}

case "${0}" in *manage_missed_conf.sh) manage_not_imported "$@"; manage_missed_conf "$@";; esac
