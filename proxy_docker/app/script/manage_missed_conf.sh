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

  local received_watches
  local data

  for address in ${watches}
  do
    if [ -n "${data}" ]; then
      data=${data}','
    fi
    data=${data}'{"id":"'${address}'","method":"listreceivedbyaddress","params":[0,false,true,"'${address}'"]}'
  done

  body_file=$(mktemp)
  echo -n "[${data}]" > ${body_file}

  for wallet in "01" "02" "03" "04"
  do
    received_watches=${received_watches}$(send_batch_to_spender_node "${body_file}" "${wallet}" | jq -Mc '.[] | select(.result != [] and .result != null) | .result[0]')
  done
  trace "[manage_missed_conf] received_watches=${received_watches}"
  rm ${body_file}

  local received_watch
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
  for received_watch in ${received_watches}
  do
    address=$(echo "${received_watch}" | jq -r '.address')
    # Getting the earliest one still being watched
    watching=$(sql "SELECT address, inserted_ts, calledback0conf FROM watching WHERE address='${address}' AND watching ORDER BY inserted_ts ASC LIMIT 1")
    trace "[manage_missed_conf] watching=${watching}"
    if [ ${#watching} -eq 0 ]; then
      trace "[manage_missed_conf] Nothing missed!"
      continue
    fi

    inserted_ts=$(date -d "$(echo "${watching}" | cut -d '|' -f2)" +%s)
    trace "[manage_missed_conf] inserted_ts=${inserted_ts}"

    # This received address is still being watched by Cyphernode watcher, let's process missed conf for
    # the transactions that happened after watching the address.
    trace "[manage_missed_conf] Let's process missed conf for the transactions that happened after watching this address"

    txids=$(echo "${received_watch}" | jq -r ".txids[]")
    trace "[manage_missed_conf] txids=${txids}"

    for txid in ${txids}; do
      trace "[manage_missed_conf] Checking txid=${txid}"

      data="{\"method\":\"gettransaction\",\"params\":[\"${txid}\",true,true]}"
      trace "[manage_missed_conf] calling method=${data}"

      for wallet in "01" "02" "03" "04"
      do
        tx=$(send_to_spender_node "${data}" ${wallet})
        returncode=$?
        trace_rc ${returncode}
        if [ "${returncode}" -eq 0 ]; then
          break
        fi
      done

      txtime=$(echo "${tx}" | jq '.result.time')

      trace "[manage_missed_conf] inserted_ts=${inserted_ts}"
      trace "[manage_missed_conf] txtime=${txtime}"

      if [ "${txtime}" -ge "${inserted_ts}" ]; then
        # Broadcast or mined after watch, we missed it!
        trace "[manage_missed_conf] Broadcast or mined after watch, we might have missed it!"
        # We skip the callbacks because do_callbacks is called right after in
        # requesthandler.executecallbacks (where we're from)
        confirmation "$(echo "${tx}" | jq -Mc '.result' | base64 -w 0)" "true"
      fi
    done
  done

  return 0
}

case "${0}" in *manage_missed_conf.sh) manage_not_imported "$@"; manage_missed_conf "$@";; esac
