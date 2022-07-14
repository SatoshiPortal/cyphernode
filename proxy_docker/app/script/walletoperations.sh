#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh
. ./bitcoin.sh

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

  # Let's lowercase bech32 addresses
  address=$(lowercase_if_bech32 "${address}")

  local response
  local id_inserted
  local tx_details
  local tx_raw_details

  response=$(send_to_spender_node "{\"method\":\"sendtoaddress\",\"params\":[\"${address}\",${amount},\"\",\"\",${subtractfeefromamount},${replaceable},${conf_target}]}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[spend] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txid=$(echo "${response}" | jq -r ".result")
    trace "[spend] txid=${txid}"

    # Let's get transaction details on the spending wallet so that we have fee information
    tx_details=$(get_transaction "${txid}" "spender")
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

  response=$(send_to_spender_node "${data}")
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
