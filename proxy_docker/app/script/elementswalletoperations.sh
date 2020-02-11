#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

elements_spend() {
  trace "Entering elements_spend()..."

  local data
  local request=${1}
  local address=$(echo "${request}" | jq -r ".address")
  trace "[elements_spend] address=${address}"
  local asset_id=$(echo "${request}" | jq ".assetId")
  trace "[elements_spend] assetId=${asset_id}"
  local amount=$(echo "${request}" | jq -r ".amount" | awk '{ printf "%.8f", $0 }')
  trace "[elements_spend] amount=${amount}"
  local response
  local id_inserted
  local tx_details
  local tx_raw_details
  local returncode

  if [ "${asset_id}" = "null" ]; then
    response=$(send_to_elements_spender_node "{\"method\":\"sendtoaddress\",\"params\":[\"${address}\",${amount}]}")
  else
    response=$(send_to_elements_spender_node "{\"method\":\"sendtoaddress\",\"params\":[\"${address}\",${amount},\"\",\"\",false,false,1,\"UNSET\",${asset_id}]}")
  fi

  returncode=$?
  trace_rc ${returncode}
  trace "[elements_spend] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txid=$(echo "${response}" | jq -r ".result")
    trace "[elements_spend] txid=${txid}"

    # Let's get transaction details on the spending wallet so that we have fee information
    tx_details=$(elements_get_transaction ${txid} "spender")
    tx_raw_details=$(elements_get_rawtransaction ${txid})

    # Amounts and fees are negative when spending so we absolute those fields
    local tx_hash=$(echo "${tx_raw_details}" | jq '.result.hash')
    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.result.details[0].amount | fabs' | awk '{ printf "%.8f", $0 }')
    local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
    local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq '.result."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo 1 || echo 0)
    local fees=$(echo "${tx_details}" | jq '.result.details[0].fee | fabs' | awk '{ printf "%.8f", $0 }')
    # Sometimes raw tx are too long to be passed as paramater, so let's write
    # it to a temp file for it to be read by sqlite3 and then delete the file
    echo "${tx_raw_details}" > rawtx-${txid}.blob

    ########################################################################################################
    # Let's publish the event if needed
    local event_message
    event_message=$(echo "${request}" | jq -er ".eventMessage")
    if [ "$?" -ne "0" ]; then
      # event_message tag null, so there's no event_message
      trace "[elements_spend] event_message="
      event_message=
    else
      # There's an event message, let's publish it!

      if [ "${asset_id}" = "null" ]; then
        trace "[elements_spend] mosquitto_pub -h broker -t elements_spend -m \"{\"txid\":\"${txid}\",\"address\":\"${address}\",\"amount\":${tx_amount},\"eventMessage\":\"${event_message}\"}\""
        response=$(mosquitto_pub -h broker -t elements_spend -m "{\"txid\":\"${txid}\",\"address\":\"${address}\",\"amount\":${tx_amount},\"eventMessage\":\"${event_message}\"}")
      else
        trace "[elements_spend] mosquitto_pub -h broker -t elements_spend -m \"{\"txid\":\"${txid}\",\"address\":\"${address}\",\"amount\":${tx_amount},\"assetId\":${asset_id},\"eventMessage\":\"${event_message}\"}\""
        response=$(mosquitto_pub -h broker -t elements_spend -m "{\"txid\":\"${txid}\",\"address\":\"${address}\",\"amount\":${tx_amount},\"assetId\":${asset_id},\"eventMessage\":\"${event_message}\"}")
      fi
      returncode=$?
      trace_rc ${returncode}
    fi
    ########################################################################################################

    # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
    sql "INSERT OR IGNORE INTO elements_tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, raw_tx, assetid) VALUES (\"${txid}\", ${tx_hash}, 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, readfile('rawtx-${txid}.blob'), ${asset_id})"
    trace_rc $?
    id_inserted=$(sql "SELECT id FROM elements_tx WHERE txid=\"${txid}\"")
    trace_rc $?
    sql "INSERT OR IGNORE INTO elements_recipient (address, amount, tx_id) VALUES (\"${address}\", ${amount}, ${id_inserted})"
    trace_rc $?

    data="{\"status\":\"accepted\""
    data="${data},\"hash\":\"${txid}\"}"

    # Delete the temp file containing the raw tx (see above)
    rm rawtx-${txid}.blob
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    data="{\"message\":${message}}"
  fi

  trace "[elements_spend] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_bumpfee() {
  trace "Entering bumpfee()..."

  local request=${1}
  local txid=$(echo "${request}" | jq -r ".txid")
  trace "[bumpfee] txid=${txid}"

  local confTarget
  local response
  local returncode

  # jq -e will have a return code of 1 if the supplied tag is null.
  confTarget=$(echo "${request}" | jq -e ".confTarget")
  if [ "$?" -ne "0" ]; then
    # confTarget tag null, so there's no confTarget
    trace "[bumpfee] confTarget="
    response=$(send_to_spender_node "{\"method\":\"bumpfee\",\"params\":[\"${txid}\"]}")
    returncode=$?
  else
    trace "[bumpfee] confTarget=${confTarget}"
    response=$(send_to_spender_node "{\"method\":\"bumpfee\",\"params\":[\"${txid}\",{\"confTarget\":${confTarget}}]}")
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

elements_get_txns_spending() {
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
elements_getbalance() {
  trace "Entering getbalance()..."

  local response
  local data='{"method":"getbalance"}'
  response=$(send_to_spender_node "${data}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[getbalance] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local balance=$(echo ${response} | jq ".result")
    trace "[getbalance] balance=${balance}"

    data="{\"balance\":${balance}}"
  else
    trace "[getbalance] Coudn't get balance!"
    data=""
  fi

  trace "[getbalance] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_getbalances() {
  trace "Entering getbalances()..."

  local response
  local data='{"method":"getbalances"}'
  response=$(send_to_spender_node "${data}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[getbalances] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local balances=$(echo ${response} | jq ".result")
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

elements_getbalancebyxpublabel() {
  trace "Entering getbalancebyxpublabel()..."

  local label=${1}
  trace "[getbalancebyxpublabel] label=${label}"
  local xpub

  xpub=$(sql "SELECT pub32 FROM watching_by_pub32 WHERE label=\"${label}\"")
  trace "[getbalancebyxpublabel] xpub=${xpub}"

  getbalancebyxpub ${xpub} "getbalancebyxpublabel"
  returncode=$?

  return ${returncode}
}

elements_getbalancebyxpub() {
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
  addresses=$(send_to_xpub_watcher_wallet ${data} | jq ".result | keys" | tr -d '\n ')
  # ./bitcoin-cli -rpcwallet=xpubwatching01.dat listunspent 0 9999999 "$addresses" | jq "[.[].amount] | add"
  data="{\"method\":\"listunspent\",\"params\":[0,9999999,${addresses}]}"
  trace "[getbalancebyxpub] data=${data}"
  balance=$(send_to_xpub_watcher_wallet ${data} | jq "[.result[].amount // 0 ] | add | . * 100000000 | trunc | . / 100000000")
  returncode=$?
  trace_rc ${returncode}
  trace "[getbalancebyxpub] balance=${balance}"

  data="{\"event\":\"${event}\",\"xpub\":\"${xpub}\",\"balance\":${balance:-0}}"

  echo "${data}"

  return "${returncode}"
}

elements_getnewaddress() {
  trace "Entering elements_getnewaddress()..."

  local address_type=${1}
  trace "[elements_getnewaddress] address_type=${address_type}"

  local response
  local data
  if [ -z "${address_type}" ]; then
    data='{"method":"getnewaddress"}'
  else
    data="{\"method\":\"getnewaddress\",\"params\":[\"\",\"${address_type}\"]}"
  fi
  response=$(send_to_elements_spender_node "${data}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[elements_getnewaddress] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local address=$(echo ${response} | jq ".result")
    trace "[elements_getnewaddress] address=${address}"

    data="{\"address\":${address}}"
  else
    trace "[elements_getnewaddress] Coudn't get a new address!"
    data=""
  fi

  trace "[elements_getnewaddress] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_addtobatching() {
  trace "Entering addtobatching()..."

  local address=${1}
  trace "[addtobatching] address=${address}"
  local amount=${2}
  trace "[addtobatching] amount=${amount}"

  sql "INSERT OR IGNORE INTO recipient (address, amount) VALUES (\"${address}\", ${amount})"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

elements_batchspend() {
  trace "Entering batchspend()..."

  local data
  local response
  local recipientswhere
  local recipientsjson
  local id_inserted
  local tx_details
  local tx_raw_details

  # We will batch all the addresses in DB without a TXID
  local batching=$(sql 'SELECT address, amount FROM recipient WHERE tx_id IS NULL')
  trace "[batchspend] batching=${batching}"

  local returncode
  local address
  local amount
  local notfirst=false
  local IFS=$'\n'
  for row in ${batching}
  do
    trace "[batchspend] row=${row}"
    address=$(echo "${row}" | cut -d '|' -f1)
    trace "[batchspend] address=${address}"
    amount=$(echo "${row}" | cut -d '|' -f2)
    trace "[batchspend] amount=${amount}"

    if ${notfirst}; then
      recipientswhere="${recipientswhere},"
      recipientsjson="${recipientsjson},"
    else
      notfirst=true
    fi

    recipientswhere="${recipientswhere}\"${address}\""
    recipientsjson="${recipientsjson}\"${address}\":${amount}"
  done

  response=$(send_to_spender_node "{\"method\":\"sendmany\",\"params\":[\"\", {${recipientsjson}}]}")
  returncode=$?
  trace_rc ${returncode}
  trace "[batchspend] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txid=$(echo "${response}" | jq -r ".result")
    trace "[batchspend] txid=${txid}"

    # Let's get transaction details on the spending wallet so that we have fee information
    tx_details=$(get_transaction ${txid} "spender")
    tx_raw_details=$(get_rawtransaction ${txid})

    # Amounts and fees are negative when spending so we absolute those fields
    local tx_hash=$(echo "${tx_raw_details}" | jq '.result.hash')
    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.result.amount | fabs' | awk '{ printf "%.8f", $0 }')
    local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
    local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq '.result."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo 1 || echo 0)
    local fees=$(echo "${tx_details}" | jq '.result.fee | fabs' | awk '{ printf "%.8f", $0 }')
    # Sometimes raw tx are too long to be passed as paramater, so let's write
    # it to a temp file for it to be read by sqlite3 and then delete the file
    echo "${tx_raw_details}" > rawtx-${txid}.blob

    # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
    sql "INSERT OR IGNORE INTO tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, raw_tx) VALUES (\"${txid}\", ${tx_hash}, 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, readfile('rawtx-${txid}.blob'))"
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      id_inserted=$(sql "SELECT id FROM tx WHERE txid=\"${txid}\"")
      trace "[batchspend] id_inserted: ${id_inserted}"
      sql "UPDATE recipient SET tx_id=${id_inserted} WHERE address IN (${recipientswhere})"
      trace_rc $?
    fi

    data="{\"status\":\"accepted\""
    data="${data},\"hash\":\"${txid}\"}"

    # Delete the temp file containing the raw tx (see above)
    rm rawtx-${txid}.blob
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    data="{\"message\":${message}}"
  fi

  trace "[batchspend] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_create_wallet() {
  trace "[Entering create_wallet()]"

  local walletname=${1}

  local rpcstring="{\"method\":\"createwallet\",\"params\":[\"${walletname}\",true]}"
  trace "[create_wallet] rpcstring=${rpcstring}"

  local result
  result=$(send_to_watcher_node ${rpcstring})
  local returncode=$?

  echo "${result}"

  return ${returncode}
}

elements_get_rawtransaction() {
  trace "Entering elements_get_rawtransaction()..."

  local txid=${1}
  trace "[elements_get_rawtransaction] txid=${txid}"
  local data="{\"method\":\"getrawtransaction\",\"params\":[\"${txid}\",true]}"
  trace "[elements_get_rawtransaction] data=${data}"
  send_to_elements_watcher_node "${data}"
  return $?
}

elements_get_transaction() {
  trace "Entering elements_get_transaction()..."

  local txid=${1}
  trace "[elements_get_transaction] txid=${txid}"
  local to_elements_spender_node=${2}
  trace "[elements_get_transaction] to_elements_spender_node=${to_elements_spender_node}"

  local data="{\"method\":\"gettransaction\",\"params\":[\"${txid}\",true]}"
  trace "[elements_get_transaction] data=${data}"
  if [ -z "${to_elements_spender_node}" ]; then
    send_to_elements_watcher_node "${data}"
  else
    send_to_elements_spender_node "${data}"
  fi
  return $?
}

elements_getwalletinfo() {
  trace "Entering elements_getwalletinfo()..."

  local data='{"method":"getwalletinfo"}'
  send_to_elements_spender_node "${data}" | jq ".result"
  return $?
}

elements_validateaddress() {
  trace "Entering elements_validateaddress()..."

  local address=${1}
  trace "[elements_validateaddress] address=${address}"
  local data="{\"method\":\"validateaddress\",\"params\":[\"${address}\"]}"
  trace "[elements_validateaddress] data=${data}"
  send_to_elements_watcher_node "${data}"
  return $?
}
