#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh
. ./bitcoin.sh

listunspent() {
  trace "Entering listunspent()..."

  local request=${1}
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  trace "[listunspent] wallet=${wallet}"
  local minconf=$(echo "${request}" | jq -r ".minconf // 0")
  trace "[listunspent] minconf=${minconf}"
  local maxconf=$(echo "${request}" | jq -r ".maxconf // null")
  trace "[listunspent] maxconf=${maxconf}"
  local addresses=$(echo "${request}" | jq -r ".addresses // []")
  trace "[listunspent] addresses=${addresses}"

  local minamount=$(echo "${request}" | jq -r ".minamount // 0")
  trace "[listunspent] minamount=${minamount}"
  local maxamount=$(echo "${request}" | jq -r ".maxamount // 9999999")
  trace "[listunspent] maxamount=${maxamount}"
  local maxcount=$(echo "${request}" | jq -r ".maxcount // 9999999")
  trace "[listunspent] maxcount=${maxcount}"

  local response

  local data='{"method":"listunspent","params":['${minconf}','${maxconf}','${addresses}',false,{"minimumAmount":'${minamount}',"maximumAmount":'${maxamount}',"maximumCount":'${maxcount}'}]}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[listunspent] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local utxos=$(echo ${response} | jq -rc ".result")
    trace "[listunspent] utxos=${utxos}"

    data="{\"utxos\":${utxos}}"
  else
    trace "[listunspent] Couldn't get utxos!"
    data=""
  fi

  trace "[listunspent] responding=${data}"
  echo "${data}"

  return ${returncode}
}

spend() {
  trace "Entering spend()..."

  local data
  local request=${1}
  local address=$(echo "${request}" | jq -r ".address")
  trace "[spend] address=${address}"
  local amount=$(echo "${request}" | jq -r ".amount" | awk '{ printf "%.8f", $0 }')
  trace "[spend] amount=${amount}"
  local conf_target=$(echo "${request}" | jq ".confTarget")
  trace "[spend] confTarget=${conf_target}"
  local replaceable=$(echo "${request}" | jq ".replaceable")
  trace "[spend] replaceable=${replaceable}"
  local subtractfeefromamount=$(echo "${request}" | jq ".subtractfeefromamount")
  trace "[spend] subtractfeefromamount=${subtractfeefromamount}"
  local wallet=$(echo "${request}" | jq ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[spend] wallet=${wallet}"
  fi

  # Let's lowercase bech32 addresses
  address=$(lowercase_if_bech32 "${address}")

  local fee_rate=$(getfeerate "${conf_target}" | jq -r ".feerate")
  trace "[spend] fee_rate=${fee_rate}"

  local response
  local id_inserted
  local tx_details
  local tx_raw_details

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "{\"method\":\"sendtoaddress\",\"params\":[\"${address}\",${amount},\"\",\"\",${subtractfeefromamount},${replaceable},null,\"unset\",false,${fee_rate}]}" "${wallet}")
  else
    response=$(send_to_spender_node "{\"method\":\"sendtoaddress\",\"params\":[\"${address}\",${amount},\"\",\"\",${subtractfeefromamount},${replaceable},null,\"unset\",false,${fee_rate}]}")
  fi
  local returncode=$?
  trace_rc ${returncode}
  trace "[spend] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txid=$(echo "${response}" | jq -r ".result")
    trace "[spend] txid=${txid}"

    # Let's get transaction details on the spending wallet so that we have fee information
    tx_details=$(get_transaction "${txid}" "spender" "${wallet}")
    tx_raw_details=$(get_rawtransaction "${txid}" | tr -d '\n')

    # Amounts and fees are negative when spending so we absolute those fields
    local tx_hash=$(echo "${tx_raw_details}" | jq -r '.result.hash')
    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.result.amount | fabs' | awk '{ printf "%.8f", $0 }')
    local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
    local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq -r '.result."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo "true" || echo "false")
    local fees=$(echo "${tx_details}" | jq '.result.fee | fabs' | awk '{ printf "%.8f", $0 }')

    ########################################################################################################
    # Let's publish the event if needed
    local event_message
    event_message=$(echo "${request}" | jq -er ".eventMessage")
    if [ "$?" -ne "0" ]; then
      # event_message tag null, so there's no event_message
      trace "[spend] event_message="
      event_message=
    else
      # There's an event message, let's publish it!

      trace "[spend] mosquitto_pub -h broker -t spend -m \"{\"txid\":\"${txid}\",\"address\":\"${address}\",\"amount\":${tx_amount},\"eventMessage\":\"${event_message}\"}\""
      response=$(mosquitto_pub -h broker -t spend -m "{\"txid\":\"${txid}\",\"address\":\"${address}\",\"amount\":${tx_amount},\"eventMessage\":\"${event_message}\"}")
      returncode=$?
      trace_rc ${returncode}
    fi
    ########################################################################################################

    # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
    id_inserted=$(sql "INSERT INTO tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, conf_target)"\
" VALUES ('${txid}', '${tx_hash}', 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, ${conf_target})"\
" RETURNING id" \
    "SELECT id FROM tx WHERE txid='${txid}'")
    trace_rc $?
    sql "INSERT INTO recipient (address, amount, tx_id) VALUES ('${address}', ${amount}, ${id_inserted})"\
" ON CONFLICT DO NOTHING"
    trace_rc $?

    data="{\"status\":\"accepted\""
    data="${data},\"txid\":\"${txid}\",\"hash\":\"${tx_hash}\",\"details\":{\"address\":\"${address}\",\"amount\":${amount},\"firstseen\":${tx_ts_firstseen},\"size\":${tx_size},\"vsize\":${tx_vsize},\"replaceable\":${tx_replaceable},\"fee\":${fees},\"subtractfeefromamount\":${subtractfeefromamount}}}"
  else
    local errorstring=$(echo "${response}" | jq -e ".error")
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      if [ "${message}" = "\"Insufficient funds\"" ]; then
        trace "[spend] mosquitto_pub -h broker -t insufficientfunds -m \"{\"method\":\"spend\",\"error\":\"${errorstring}\"}\""
        mosquitto_pub -h broker -t insufficientfunds -m "{\"method\":\"spend\",\"error\":\"${errorstring}\"}"
      fi

      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[spend] responding=${data}"
  echo "${data}"

  return ${returncode}
}

sendmany() {
  trace "Entering sendmany()..."

  local data
  local request=${1}
  local amounts=$(echo "${request}" | jq -r ".amounts")
  trace "[sendmany] amounts=${amounts}"
  local conf_target=$(echo "${request}" | jq ".confTarget")
  trace "[sendmany] confTarget=${conf_target}"
  local replaceable=$(echo "${request}" | jq ".replaceable")
  trace "[sendmany] replaceable=${replaceable}"
  local fee_rate=$(echo "${request}" | jq ".feeRate")
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[sendmany] wallet=${wallet}"
  fi

  local response
  local id_inserted
  local tx_details
  local tx_raw_details

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "{\"method\":\"sendmany\",\"params\":[\"\", ${amounts},6,\"\",[],${replaceable},${conf_target},\"unset\",${fee_rate}]}" "${wallet}")
  else
    response=$(send_to_spender_node "{\"method\":\"sendmany\",\"params\":[\"\", ${amounts},6,\"\",[],${replaceable},${conf_target},\"unset\",${fee_rate}]}")
  fi
  local returncode=$?
  trace_rc ${returncode}
  trace "[sendmany] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txid=$(echo "${response}" | jq -r ".result")
    trace "[sendmany] txid=${txid}"

    # Let's get transaction details on the spending wallet so that we have fee information
    tx_details=$(get_transaction "${txid}" "spender" "${wallet}")
    tx_raw_details=$(get_rawtransaction "${txid}" | tr -d '\n')

    # Amounts and fees are negative when spending so we absolute those fields
    local tx_hash=$(echo "${tx_raw_details}" | jq -r '.result.hash')
    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.result.amount | fabs' | awk '{ printf "%.8f", $0 }')
    local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
    local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq -r '.result."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo "true" || echo "false")
    local fees=$(echo "${tx_details}" | jq '.result.fee | fabs' | awk '{ printf "%.8f", $0 }')

    ########################################################################################################
    # Let's publish the event if needed
    local event_message
    event_message=$(echo "${request}" | jq -er ".eventMessage")
    if [ "$?" -ne "0" ]; then
      # event_message tag null, so there's no event_message
      trace "[sendmany] event_message="
      event_message=
    else
      # There's an event message, let's publish it!

      trace "[sendmany] mosquitto_pub -h broker -t sendmany -m \"{\"txid\":\"${txid}\",\"amounts\":${amounts},\"tx_amount\":${tx_amount},\"fees\":\"${fees}\",\"eventMessage\":\"${event_message}\"}\""
      response=$(mosquitto_pub -h broker -t sendmany -m "{\"txid\":\"${txid}\",\"amounts\":${amounts},\"tx_amount\":${tx_amount},\"fees\":\"${fees}\",\"eventMessage\":\"${event_message}\"}")
      returncode=$?
      trace_rc ${returncode}
    fi
    ########################################################################################################

    # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
    id_inserted=$(sql "INSERT INTO tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, conf_target)"\
" VALUES ('${txid}', '${tx_hash}', 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, ${conf_target})"\
" RETURNING id" \
    "SELECT id FROM tx WHERE txid='${txid}'")
    trace_rc $?
    
    echo "${amounts}" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r address amount; do
      sql "INSERT INTO recipient (address, amount, tx_id) VALUES ('${address}', ${amount}, ${id_inserted})"\
" ON CONFLICT DO NOTHING"
      trace_rc $?
    done
#    sql "INSERT INTO recipient (address, amount, tx_id) VALUES ('${address}', ${amount}, ${id_inserted})"\
#" ON CONFLICT DO NOTHING"
#    trace_rc $?

    data="{\"status\":\"accepted\""
    data="${data},\"txid\":\"${txid}\",\"hash\":\"${tx_hash}\",\"details\":{\"amounts\":${amounts},\"tx_amount\":${tx_amount},\"firstseen\":${tx_ts_firstseen},\"size\":${tx_size},\"vsize\":${tx_vsize},\"replaceable\":${tx_replaceable},\"fee\":${fees}}}"
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[sendmany] responding=${data}"
  echo "${data}"

  return ${returncode}
}

createrawtransaction() {
  trace "Entering createrawtransaction()..."

  local request=${1}
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[createrawtransaction] wallet=${wallet}"
  fi
  local inputs=$(echo "${request}" | jq -r ".inputs")
  trace "[createrawtransaction] inputs=${inputs}"
  local outputs=$(echo "${request}" | jq -r ".outputs")
  trace "[createrawtransaction] outputs=${outputs}"
  local locktime=$(echo "${request}" | jq -r ".locktime // null")
  trace "[createrawtransaction] locktime=${locktime}"
  local replaceable=$(echo "${request}" | jq -r ".replaceable // true")

  local response

  local data='{"method":"createrawtransaction","params":['${inputs}','${outputs}','${locktime}','${replaceable}']}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[createrawtransaction] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local rawtx=$(echo ${response} | jq -rc ".result")
    trace "[createrawtransaction] rawtx=${rawtx}"

    data="{\"hex\":\"${rawtx}\"}"
  else
    trace "[createrawtransaction] Couldn't get rawtx!"
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[createrawtransaction] responding=${data}"
  echo "${data}"

  return ${returncode}
}

decoderawtransaction() {
  trace "Entering decoderawtransaction()..."

  local request=${1}
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[decoderawtransaction] wallet=${wallet}"
  fi
  local rawtx=$(echo "${request}" | jq -r ".hex")
  trace "[decoderawtransaction] rawtx=${rawtx}"

  local response

  local data='{"method":"decoderawtransaction","params":["'${rawtx}'"]}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[decoderawtransaction] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local tx=$(echo ${response} | jq -rc ".result")
    trace "[decoderawtransaction] tx=${tx}"

    data="{\"tx\":${tx}}"
  else
    trace "[decoderawtransaction] Couldn't decode tx!"
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[decoderawtransaction] responding=${data}"
  echo "${data}"

  return ${returncode}
}

fundrawtransaction() {
  trace "Entering fundrawtransaction()..."

  local request=${1}
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[fundrawtransaction] wallet=${wallet}"
  fi
  local rawtx=$(echo "${request}" | jq -r ".hex")
  trace "[fundrawtransaction] rawtx=${rawtx}"
  local options=$(echo "${request}" | jq -r ".options")
  trace "[fundrawtransaction] options=${options}"

  local response

  local data='{"method":"fundrawtransaction","params":["'${rawtx}'",'${options}']}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[fundrawtransaction] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local data=$(echo ${response} | jq -rc ".result")
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[fundrawtransaction] responding=${data}"

  echo "${data}"

  return ${returncode}
}

signrawtransaction() {
  trace "Entering signrawtransaction()..."

  local request=${1}
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[signrawtransaction] wallet=${wallet}"
  fi
  local rawtx=$(echo "${request}" | jq -r ".hex")
  trace "[signrawtransaction] rawtx=${rawtx}"

  local response

  local data='{"method":"signrawtransactionwithwallet","params":["'${rawtx}'"]}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[signrawtransaction] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local data=$(echo ${response} | jq -rc ".result")
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[signrawtransaction] responding=${data}"

  echo "${data}"

  return ${returncode}
}

sendrawtransaction() {
  trace "Entering sendrawtransaction()..."

  local request=${1}
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[sendrawtransaction] wallet=${wallet}"
  fi
  local rawtx=$(echo "${request}" | jq -r ".hex")
  trace "[sendrawtransaction] rawtx=${rawtx}"
  local maxfeerate=$(echo "${request}" | jq -r ".maxfeerate // 0.1")
  trace "[sendrawtransaction] maxfeerate=${maxfeerate}"

  local response

  local data='{"method":"sendrawtransaction","params":["'${rawtx}'",'${maxfeerate}']}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[sendrawtransaction] response=${response}"

  echo "${response}"

  return ${returncode}
}

bumpfee() {
  trace "Entering bumpfee()..."

  local request=${1}
  local txid=$(echo "${request}" | jq -r ".txid")
  trace "[bumpfee] txid=${txid}"
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  trace "[bumpfee] wallet=${wallet}"

  local confTarget
  local response
  local returncode

  data="{\"method\":\"bumpfee\",\"params\":[\"${txid}\""

  # jq -e will have a return code of 1 if the supplied tag is null.
  confTarget=$(echo "${request}" | jq -e ".confTarget")
  if [ "$?" -ne "0" ]; then
    # confTarget tag null, so there's no confTarget
    trace "[bumpfee] confTarget="
  else
    data="${data},{\"confTarget\":${confTarget}}"
    trace "[bumpfee] confTarget=${confTarget}"
  fi
  data="${data}]}"

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
    returncode=$?
  else
    response=$(send_to_spender_node "${data}")
    returncode=$?
  fi

  trace_rc ${returncode}
  trace "[bumpfee] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    trace "[bumpfee] error!"
  else
    trace "[bumpfee] success!"
  fi

  echo "${response}"

  return ${returncode}
}

get_txns_spending() {
  trace "Entering get_txns_spending()... with count: $1 , skip: $2"
  local count="$1"
  local skip="$2"
  local response
  local data="{\"method\":\"listtransactions\",\"params\":[\"*\",${count:-10},${skip:-0}]}"
  response=$(send_to_spender_node "${data}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[get_txns_spending] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txns=$(echo ${response} | jq -rc ".result")
    trace "[get_txns_spending] txns=${txns}"

    data="{\"txns\":${txns}}"
  else
    trace "[get_txns_spending] Coudn't get txns!"
    data=""
  fi

  trace "[get_txns_spending] responding=${data}"
  echo "${data}"

  return ${returncode}
}

getbalance() {
  trace "Entering getbalance()..."

  local wallet=${1:-}
  local response
  local data='{"method":"getbalance"}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[getbalance] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local balance=$(echo ${response} | jq ".result")
    trace "[getbalance] balance=${balance}"

    data="{\"balance\":${balance}}"
  else
    trace "[getbalance] Couldn't get balance!"
    data=""
  fi

  trace "[getbalance] responding=${data}"
  echo "${data}"

  return ${returncode}
}

getbalances() {
  trace "Entering getbalances()..."

  local wallet=${1:-}
  local response
  local data='{"method":"getbalances"}'
  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi
  local returncode=$?
  trace_rc ${returncode}
  trace "[getbalances] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local balances=$(echo "${response}" | jq ".result")
    trace "[getbalances] balances=${balances}"

    data="{\"balances\":${balances}}"
  else
    trace "[getbalances] Couldn't get balances!"
    data=""
  fi

  trace "[getbalances] responding=${data}"
  echo "${data}"

  return ${returncode}
}

getbalancebyxpublabel() {
  trace "Entering getbalancebyxpublabel()..."

  local label=${1}
  trace "[getbalancebyxpublabel] label=${label}"
  local xpub

  xpub=$(sql "SELECT pub32 FROM watching_by_pub32 WHERE label='${label}'")
  trace "[getbalancebyxpublabel] xpub=${xpub}"

  getbalancebyxpub "${xpub}" "getbalancebyxpublabel"
  returncode=$?

  return ${returncode}
}

getbalancebyxpub() {
  trace "Entering getbalancebyxpub()..."

  # ./bitcoin-cli -rpcwallet=xpubwatching01.dat listunspent 0 9999999 "$(./bitcoin-cli -rpcwallet=xpubwatching01.dat getaddressesbylabel upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb | jq "keys" | tr -d '\n ')" | jq "[.[].amount] | add"

  local xpub=${1}
  trace "[getbalancebyxpub] xpub=${xpub}"

  # If called from getbalancebyxpublabel, set the correct event for response
  local event=${2:-"getbalancebyxpub"}
  trace "[getbalancebyxpub] event=${event}"
  local addresses
  local balance
  local data
  local returncode

  # addresses=$(./bitcoin-cli -rpcwallet=xpubwatching01.dat getaddressesbylabel upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb | jq "keys" | tr -d '\n ')
  data="{\"method\":\"getaddressesbylabel\",\"params\":[\"${xpub}\"]}"
  trace "[getbalancebyxpub] data=${data}"
  addresses=$(send_to_xpub_watcher_wallet "${data}" | jq ".result | keys" | tr -d '\n ')
  # ./bitcoin-cli -rpcwallet=xpubwatching01.dat listunspent 0 9999999 "$addresses" | jq "[.[].amount] | add"
  data="{\"method\":\"listunspent\",\"params\":[0,9999999,${addresses}]}"
  trace "[getbalancebyxpub] data=${data}"
  balance=$(send_to_xpub_watcher_wallet "${data}" | jq "[.result[].amount // 0 ] | add | . * 100000000 | trunc | . / 100000000")
  returncode=$?
  trace_rc ${returncode}
  trace "[getbalancebyxpub] balance=${balance}"

  data="{\"event\":\"${event}\",\"xpub\":\"${xpub}\",\"balance\":${balance:-0}}"

  echo "${data}"

  return "${returncode}"
}

getnewaddress() {
  trace "Entering getnewaddress()..."

  local address_type=${1}
  trace "[getnewaddress] address_type=${address_type}"

  local label=${2}
  trace "[getnewaddress] label=${label}"

  local wallet=${3}
  trace "[getnewaddress] wallet=${wallet}"

  local response
  local jqop
  local addedfieldstoresponse
  local data='{"method":"getnewaddress"}'
  if [ -n "${address_type}" ] || [ -n "${label}" ]; then
    jqop='. += {"params":{}}'
    if [ -n "${label}" ]; then
      jqop=${jqop}' | .params += {"label":"'${label}'"}'
      addedfieldstoresponse=' | . += {"label":"'${label}'"}'
    fi
    if [ -n "${address_type}" ]; then
      jqop=${jqop}' | .params += {"address_type":"'${address_type}'"}'
      addedfieldstoresponse=' | . += {"address_type":"'${address_type}'"}'
    fi
    trace "[getnewaddress] jqop=${jqop}"
    trace "[getnewaddress] addedfieldstoresponse=${addedfieldstoresponse}"

    data=$(echo "${data}" | jq -rc "${jqop}")
  fi
  trace "[getnewaddress] data=${data}"

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi
  local returncode=$?
  trace_rc ${returncode}
  trace "[getnewaddress] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local address=$(echo ${response} | jq ".result")
    trace "[getnewaddress] address=${address}"

    data='{"address":'${address}'}'
    if [ -n "${jqop}" ]; then
      data=$(echo "${data}" | jq -rc ".${addedfieldstoresponse}")
      trace "[getnewaddress] data=${data}"
    fi
  else
    trace "[getnewaddress] Coudn't get a new address!"
    data=""
  fi

  trace "[getnewaddress] responding=${data}"
  echo "${data}"

  return ${returncode}
}

lockunspent() {
  trace "Entering lockunspent()..."

  local request=${1}
  local unlock=$(echo "${request}" | jq -r ".unlock // false")
  local utxos=$(echo "${request}" | jq -r ".utxos")
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  local response
  local data='{"method":"lockunspent","params":['${unlock}','${utxos}']}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[lockunspent] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local success=$(echo ${response} | jq ".result")
    trace "[lockunspent] success=${success}"

    data="{\"success\":${success}}"
  else
    trace "[lockunspent] Couldn't lock/unlock unspent!"
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[lockunspent] responding=${data}"
  echo "${data}"

  return ${returncode}
}

listlockunspent() {
  trace "Entering listlockunspent()..."

  local wallet=${1}
  local response
  local data='{"method":"listlockunspent"}'

  if [ -n "${wallet}" ]; then
    response=$(send_to_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_spender_node "${data}")
  fi

  local returncode=$?
  trace_rc ${returncode}
  trace "[listlockunspent] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local locked_utxos=$(echo ${response} | jq ".result")
    trace "[listlockunspent] locked_utxos=${locked_utxos}"

    data="{\"locked_utxos\":${locked_utxos}}"
  else
    trace "[listlockunspent] Couldn't list locked unspent!"
    local message=$(echo "${response}" | jq -e ".error.message")
    if [ -n "${message}" ]; then
      data="{\"message\":${message}}"
    else
      data="{\"message\":null}"
    fi
  fi

  trace "[listlockunspent] responding=${data}"
  echo "${data}"

  return ${returncode}
}

create_wallet() {
  trace "[Entering create_wallet()]"

  local walletname=${1}

  local rpcstring="{\"method\":\"createwallet\",\"params\":[\"${walletname}\",true]}"
  trace "[create_wallet] rpcstring=${rpcstring}"

  local result
  result=$(send_to_watcher_node "${rpcstring}")
  local returncode=$?

  echo "${result}"

  return ${returncode}
}
