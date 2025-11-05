#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./elements_importaddress.sh
. ./elements_confirmation.sh

elements_manage_not_imported() {
  # When we tried to import watched addresses in the watching node,
  # if it didn't succeed, we try again here.

  trace "[Entering elements_manage_not_imported()]"

  local watches=$(sql 'SELECT address, label FROM elements_watching WHERE watching AND NOT imported')
  trace "[elements_manage_not_imported] watches=${watches}"

  local result
  local returncode
  local IFS="
"
  for row in ${watches}
  do
    address=$(echo "${row}" | cut -d '|' -f1)
    label=$(echo "${row}" | cut -d '|' -f2)
    result=$(elements_importaddress_rpc "${address}" "${label}")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      sql "UPDATE elements_watching SET imported=true WHERE address='${address}'"
    fi
  done

  return 0
}

elements_manage_missed_conf() {
  # Maybe we missed 0-conf or 1-conf watched txs, because we were down or no network or
  # whatever, so we look at what might be missed and do confirmations.

  # The strategy here: get the list of watched addresses, see if they received something on the Elements node,
  # and for each ones that received something after the watching timestamp, we kinda missed them...

  trace "[Entering elements_manage_missed_conf()]"

  local watches=$(sql "SELECT DISTINCT address FROM elements_watching w LEFT JOIN elements_watching_tx ON w.id = elements_watching_id LEFT JOIN elements_tx t ON t.id = elements_tx_id WHERE watching AND imported ORDER BY address")
  trace "[elements_manage_missed_conf] watches=${watches}"
  if [ ${#watches} -eq 0 ]; then
    trace "[elements_manage_missed_conf] Nothing missed!"
    return 0
  fi

  local received_watches
  local data

  for address in ${watches}
  do
    if [ -n "${data}" ]; then
      data=${data}','
    fi
    data=${data}'{"id":"'${address}'","method":"listreceivedbyaddress","params":[0,true,true,"'${address}'"]}'
  done

  body_file=$(mktemp)
  echo -n "[${data}]" > ${body_file}

  for wallet in "01" "02" "03" "04"
  do
    received_watches=${received_watches}$(send_batch_to_elements_spender_node "${body_file}" "${wallet}" | jq -Mc '.[] | select(.result != [] and .result != null) | .result[0]')
  done
  trace "[elements_manage_missed_conf] received_watches=${received_watches}"
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
    watching=$(sql "SELECT address, inserted_ts, calledback0conf FROM elements_watching WHERE address='${address}' AND watching ORDER BY inserted_ts ASC LIMIT 1")
    trace "[elements_manage_missed_conf] watching=${watching}"
    if [ ${#watching} -eq 0 ]; then
      trace "[elements_manage_missed_conf] Nothing missed!"
      continue
    fi

    inserted_ts=$(date -d "$(echo "${watching}" | cut -d '|' -f2)" +%s)
    trace "[elements_manage_missed_conf] inserted_ts=${inserted_ts}"

    # This received address is still being watched by Cyphernode watcher, let's process missed conf for
    # the transactions that happened after watching the address.
    trace "[elements_manage_missed_conf] Let's process missed conf for the transactions that happened after watching this address"

    txids=$(echo "${received_watch}" | jq -r ".txids[]")
    trace "[elements_manage_missed_conf] txids=${txids}"

    for txid in ${txids}; do
      trace "[elements_manage_missed_conf] Checking txid=${txid}"

      data="{\"method\":\"gettransaction\",\"params\":[\"${txid}\",true,true]}"
      trace "[elements_manage_missed_conf] calling method=${data}"

      for wallet in "01" "02" "03" "04"
      do
        tx=$(send_to_elements_spender_node "${data}" ${wallet})
        returncode=$?
        trace_rc ${returncode}
        if [ "${returncode}" -eq 0 ]; then
          break
        fi
      done

      txtime=$(echo "${tx}" | jq '.result.time')

      trace "[elements_manage_missed_conf] inserted_ts=${inserted_ts}"
      trace "[elements_manage_missed_conf] txtime=${txtime}"

      if [ "${txtime}" -ge "${inserted_ts}" ]; then
        # Broadcast or mined after watch, we missed it!
        trace "[elements_manage_missed_conf] Broadcast or mined after watch, we might have missed it!"
        # We skip the callbacks because do_callbacks is called right after in
        # requesthandler.executecallbacks (where we're from)
        elements_confirmation "$(echo "${tx}" | jq -Mc '.result' | base64 -w 0)" "true"
      fi
    done
  done

  return 0
}

case "${0}" in *elements_manage_missed_conf.sh) elements_manage_not_imported "$@"; elements_manage_missed_conf "$@";; esac
