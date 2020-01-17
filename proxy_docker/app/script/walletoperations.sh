#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

spend() {
  trace "Entering spend()..."

  local data
  local request=${1}
  local address=$(echo "${request}" | jq -r ".address")
  trace "[spend] address=${address}"
  local amount=$(echo "${request}" | jq ".amount" | awk '{ printf "%.8f", $0 }')
  trace "[spend] amount=${amount}"
  local response
  local id_inserted
  local tx_details
  local tx_raw_details

  response=$(send_to_spender_node "{\"method\":\"sendtoaddress\",\"params\":[\"${address}\",${amount}]}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[spend] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txid=$(echo "${response}" | jq -r ".result")
    trace "[spend] txid=${txid}"

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
    local rawtx=$(echo "${tx_details}" | jq '.result.hex')

    # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
    sql "INSERT OR IGNORE INTO tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, raw_tx) VALUES (\"${txid}\", ${tx_hash}, 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, ${rawtx})"
    trace_rc $?
    id_inserted=$(sql "SELECT id FROM tx WHERE txid=\"${txid}\"")
    trace_rc $?
    sql "INSERT OR IGNORE INTO recipient (address, amount, tx_id) VALUES (\"${address}\", ${amount}, ${id_inserted})"
    trace_rc $?

    data="{\"status\":\"accepted\""
    data="${data},\"hash\":\"${txid}\"}"
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    data="{\"message\":${message}}"
  fi

  trace "[spend] responding=${data}"
  echo "${data}"

  return ${returncode}
}

bumpfee() {
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

getbalance() {
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

getbalances() {
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
    trace "[getbalances] Coudn't get balances!"
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

  xpub=$(sql "SELECT pub32 FROM watching_by_pub32 WHERE label=\"${label}\"")
  trace "[getbalancebyxpublabel] xpub=${xpub}"

  getbalancebyxpub ${xpub} "getbalancebyxpublabel"
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
  data="{\"method\":\"getaddressesbylabel\",\"params\":[${xpub}]}"
  trace "[getbalancebyxpub] data=${data}"
  addresses=$(send_to_xpub_watcher_wallet ${data} | jq "keys" | tr -d '\n ')

  # ./bitcoin-cli -rpcwallet=xpubwatching01.dat listunspent 0 9999999 "$addresses" | jq "[.[].amount] | add"

  data="{\"method\":\"listunspent\",\"params\":[0, 9999999, \"${addresses}\"]}"
  trace "[getbalancebyxpub] data=${data}"
  balance=$(send_to_xpub_watcher_wallet ${data} | jq "[.[].amount] | add | . * 100000000 | trunc | . / 100000000")
  returncode=$?
  trace_rc ${returncode}
  trace "[getbalancebyxpub] balance=${balance}"

  data="{\"event\":\"${event}\",\"xpub\":\"${xpub}\",\"balance\":${balance}}"

  echo "${data}"

  return ${returncode}
}

getnewaddress() {
  trace "Entering getnewaddress()..."

  local address_type=${1}
  trace "[getnewaddress] address_type=${address_type}"

  local response
  local data
  if [ -z "${address_type}" ]; then
    data='{"method":"getnewaddress"}'
  else
    data="{\"method\":\"getnewaddress\",\"params\":[\"\",\"${address_type}\"]}"
  fi
  response=$(send_to_spender_node "${data}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[getnewaddress] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local address=$(echo ${response} | jq ".result")
    trace "[getnewaddress] address=${address}"

    data="{\"address\":${address}}"
  else
    trace "[getnewaddress] Coudn't get a new address!"
    data=""
  fi

  trace "[getnewaddress] responding=${data}"
  echo "${data}"

  return ${returncode}
}

addtobatching() {
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

batchspend() {
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
    local rawtx=$(echo "${tx_details}" | jq '.result.hex')

    # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
    sql "INSERT OR IGNORE INTO tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, raw_tx) VALUES (\"${txid}\", ${tx_hash}, 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, ${rawtx})"
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
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    data="{\"message\":${message}}"
  fi

  trace "[batchspend] responding=${data}"
  echo "${data}"

  return ${returncode}
}

create_wallet() {
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

