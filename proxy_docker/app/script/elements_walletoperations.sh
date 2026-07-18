#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

elements_spend() {
  trace "Entering elements_spend()..."

  local data
  local request=${1}
  local address=$(echo "${request}" | jq -r ".address")
  trace "[elements_spend] address=${address}"
  local assetid=$(echo "${request}" | jq -r ".assetId")
  trace "[elements_spend] assetId=${assetid}"
  local amount=$(echo "${request}" | jq -r ".amount" | awk '{ printf "%.8f", $0 }')
  trace "[elements_spend] amount=${amount}"
  local conf_target=$(echo "${request}" | jq ".confTarget")
  trace "[elements_spend] confTarget=${conf_target}"
  local replaceable=$(echo "${request}" | jq ".replaceable")
  trace "[elements_spend] replaceable=${replaceable}"
  local subtractfeefromamount=$(echo "${request}" | jq ".subtractfeefromamount")
  trace "[elements_spend] subtractfeefromamount=${subtractfeefromamount}"
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[spend] wallet=${wallet}"
  fi
  local response
  local id_inserted
  local tx_details
  local tx_raw_details
  local returncode
  local event_returncode

  data=$(jq -nc \
    --arg dest_address "${address}" \
    --argjson spend_amount "${amount}" \
    --argjson subtract_fee "${subtractfeefromamount}" \
    --argjson rbf "${replaceable}" \
    --argjson conf_target "${conf_target}" \
    --arg asset_id "${assetid}" '
    {method: "sendtoaddress"}
    | if $asset_id == "null" then
        .params = [$dest_address, $spend_amount, "", "", $subtract_fee, $rbf, $conf_target]
      else
        .params = [$dest_address, $spend_amount, "", "", $subtract_fee, $rbf, $conf_target, "UNSET", null, $asset_id]
      end
  ')
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    echo '{"message":"invalid spend request"}'
    return "${returncode}"
  fi

  if [ -n "${wallet}" ]; then
    response=$(send_to_elements_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_elements_spender_node "${data}")
  fi

  returncode=$?
  trace_rc ${returncode}
  trace "[elements_spend] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txid=$(echo "${response}" | jq -r ".result")
    trace "[elements_spend] txid=${txid}"

    # Let's get transaction details on the spending wallet so that we have fee information
    tx_details=$(elements_get_transaction "${txid}" "spender" "${wallet}")
    tx_raw_details=$(elements_get_rawtransaction "${txid}" | tr -d '\n')

    # Amounts and fees are negative when spending so we absolute those fields
    local tx_hash=$(echo "${tx_raw_details}" | jq -r '.result.hash')
    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.result.details[0].amount | fabs' | awk '{ printf "%.8f", $0 }')
    local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
    local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq -r '.result."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo "true" || echo "false")
    local fees=$(echo "${tx_details}" | jq '.result.details[0].fee | fabs' | awk '{ printf "%.8f", $0 }')

    # We need to get the corresponding unblinded address to work around the elements gettransaction bug with blinded addresses
    local unblinded_address=$(elements_getaddressinfo "${address}" true "${wallet}" | jq -r ".result.unconfidential")
    trace "[elements_spend] unblinded_address=${unblinded_address}"

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

      if [ "${assetid}" = "null" ]; then
        trace "[elements_spend] mosquitto_pub -h broker -t elements_spend -m \"{\"txid\":\"${txid}\",\"address\":\"${address}\",\"unblinded_address\":\"${unblinded_address}\",\"amount\":${tx_amount},\"eventMessage\":\"${event_message}\"}\""
        response=$(mosquitto_pub -h broker -t elements_spend -m "{\"txid\":\"${txid}\",\"address\":\"${address}\",\"unblinded_address\":\"${unblinded_address}\",\"amount\":${tx_amount},\"eventMessage\":\"${event_message}\"}")
      else
        trace "[elements_spend] mosquitto_pub -h broker -t elements_spend -m \"{\"txid\":\"${txid}\",\"address\":\"${address}\",\"unblinded_address\":\"${unblinded_address}\",\"amount\":${tx_amount},\"assetId\":\"${assetid}\",\"eventMessage\":\"${event_message}\"}\""
        response=$(mosquitto_pub -h broker -t elements_spend -m "{\"txid\":\"${txid}\",\"address\":\"${address}\",\"unblinded_address\":\"${unblinded_address}\",\"amount\":${tx_amount},\"assetId\":\"${assetid}\",\"eventMessage\":\"${event_message}\"}")
      fi
      event_returncode=$?
      trace_rc ${event_returncode}
      if [ "${event_returncode}" -ne 0 ]; then
        trace "[elements_spend] Failed to publish the optional spend event after broadcasting ${txid}"
      fi
    fi
    ########################################################################################################

    # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
    id_inserted=$(sql "INSERT INTO elements_tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable)"\
" VALUES ('${txid}', '${tx_hash}', 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable})"\
" RETURNING id" \
    "SELECT id FROM elements_tx WHERE txid='${txid}'")
    trace_rc $?
    sql "INSERT INTO elements_recipient (address, unblinded_address, amount, elements_tx_id, assetid) VALUES ('${address}', '${unblinded_address}', ${amount}, ${id_inserted}, '${assetid}')"\
" ON CONFLICT DO NOTHING"
    trace_rc $?

    data="{\"status\":\"accepted\""
    data="${data},\"txid\":\"${txid}\",\"hash\":\"${tx_hash}\",\"details\":{\"address\":\"${address}\",\"unblindedAddress\":\"${unblinded_address}\",\"amount\":${amount},\"assetId\":\"${assetid}\",\"firstseen\":${tx_ts_firstseen},\"size\":${tx_size},\"vsize\":${tx_vsize},\"replaceable\":${tx_replaceable},\"fee\":${fees},\"subtractfeefromamount\":${subtractfeefromamount}}}"
  else
    local message=$(echo "${response}" | jq -e ".error.message")
    data="{\"message\":${message}}"
  fi

  trace "[elements_spend] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_bumpfee() {
  trace "Entering elements_bumpfee()..."

  local request=${1}
  local txid=$(echo "${request}" | jq -r ".txid")
  trace "[elements_bumpfee] txid=${txid}"

  local confTarget
  local data
  local response
  local returncode

  # jq -e will have a return code of 1 if the supplied tag is null.
  confTarget=$(echo "${request}" | jq -e ".confTarget")
  if [ "$?" -ne "0" ]; then
    # confTarget tag null, so there's no confTarget
    trace "[elements_bumpfee] confTarget="
    data=$(jq -nc --arg txid "${txid}" '{method:"bumpfee",params:[$txid]}')
    returncode=$?
  else
    trace "[elements_bumpfee] confTarget=${confTarget}"
    data=$(jq -nc --arg txid "${txid}" --argjson conf_target "${confTarget}" '{method:"bumpfee",params:[$txid,{confTarget:$conf_target}]}')
    returncode=$?
  fi
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  response=$(send_to_elements_spender_node "${data}")
  returncode=$?

  trace_rc ${returncode}
  trace "[elements_bumpfee] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    trace "[elements_bumpfee] error!"
  else
    trace "[elements_bumpfee] success!"
  fi

  echo "${response}"

  return ${returncode}
}

elements_get_txns_spending() {
  trace "Entering elements_get_txns_spending()... with count: $1 , skip: $2"
  local count="$1"
  local skip="$2"
  local response
  local data="{\"method\":\"listtransactions\",\"params\":[\"*\",${count:-10},${skip:-0}]}"
  response=$(send_to_elements_spender_node "${data}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[elements_get_txns_spending] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local txns=$(echo ${response} | jq -rc ".result")
    trace "[elements_get_txns_spending] txns=${txns}"

    data="{\"txns\":${txns}}"
  else
    trace "[elements_get_txns_spending] Coudn't get txns!"
    data=""
  fi

  trace "[elements_get_txns_spending] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_getbalance() {
  trace "Entering elements_getbalance()..."

  local wallet=${1:-}
  local response
  local data='{"method":"getbalance"}'
  if [ -n "${wallet}" ]; then
    response=$(send_to_elements_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_elements_spender_node "${data}")
  fi
  local returncode=$?
  trace_rc ${returncode}
  trace "[elements_getbalance] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local balance=$(echo ${response} | jq ".result")
    trace "[elements_getbalance] balance=${balance}"

    data="{\"balance\":${balance}}"
  else
    trace "[elements_getbalance] Coudn't get balance!"
    data=""
  fi

  trace "[elements_getbalance] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_getbalances() {
  trace "Entering elements_getbalances()..."

  local response
  local data='{"method":"getbalances"}'
  response=$(send_to_elements_spender_node "${data}")
  local returncode=$?
  trace_rc ${returncode}
  trace "[elements_getbalances] response=${response}"

  if [ "${returncode}" -eq 0 ]; then
    local balances=$(echo "${response}" | jq ".result")
    trace "[elements_getbalances] balances=${balances}"

    data="{\"balances\":${balances}}"
  else
    trace "[elements_getbalances] Couldn't get balances!"
    data=""
  fi

  trace "[elements_getbalances] responding=${data}"
  echo "${data}"

  return ${returncode}
}

elements_getbalancebyxpublabel() {
  trace "Entering elements_getbalancebyxpublabel()..."

  local label=${1}
  trace "[elements_getbalancebyxpublabel] label=${label}"
  local xpub

  xpub=$(sql "SELECT pub32 FROM elements_watching_by_pub32 WHERE label='${label}'")
  trace "[elements_getbalancebyxpublabel] xpub=${xpub}"

  elements_getbalancebyxpub "${xpub}" "elements_getbalancebyxpublabel"
  returncode=$?

  return ${returncode}
}

elements_getbalancebyxpub() {
  trace "Entering elements_getbalancebyxpub()..."

  # ./bitcoin-cli -rpcwallet=xpubwatching01.dat listunspent 0 9999999 "$(./bitcoin-cli -rpcwallet=xpubwatching01.dat getaddressesbylabel upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb | jq "keys" | tr -d '\n ')" | jq "[.[].amount] | add"

  local xpub=${1}
  trace "[elements_getbalancebyxpub] xpub=${xpub}"

  # If called from getbalancebyxpublabel, set the correct event for response
  local event=${2:-"elements_getbalancebyxpub"}
  trace "[elements_getbalancebyxpub] event=${event}"
  local addresses
  local balance
  local data
  local response
  local returncode

  # addresses=$(./elements-cli -rpcwallet=xpubwatching01.dat getaddressesbylabel upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb | jq "keys" | tr -d '\n ')
  data=$(jq -nc --arg xpub "${xpub}" '{method:"getaddressesbylabel",params:[$xpub]}')
  returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  trace "[elements_getbalancebyxpub] data=${data}"
  response=$(send_to_xpub_elements_watcher_wallet "${data}")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne 0 ]; then
    echo "${response}"
    return "${returncode}"
  fi
  addresses=$(echo "${response}" | jq -Mc '.result | keys')
  returncode=$?
  trace_rc ${returncode}
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  # ./elements-cli -rpcwallet=xpubwatching01.dat listunspent 0 9999999 "$addresses" | jq "[.[].amount] | add"
  data="{\"method\":\"listunspent\",\"params\":[0,9999999,${addresses}]}"
  trace "[elements_getbalancebyxpub] data=${data}"
  response=$(send_to_xpub_elements_watcher_wallet "${data}")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne 0 ]; then
    echo "${response}"
    return "${returncode}"
  fi
  balance=$(echo "${response}" | jq "[.result[].amount // 0 ] | add | . * 100000000 | trunc | . / 100000000")
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_getbalancebyxpub] balance=${balance}"

  data="{\"event\":\"${event}\",\"xpub\":\"${xpub}\",\"balance\":${balance:-0}}"

  echo "${data}"

  return "${returncode}"
}

elements_getnewaddress() {
  trace "Entering elements_getnewaddress()..."

  local address_type=${1:-}
  trace "[elements_getnewaddress] address_type=${address_type}"

  local label=${2:-}
  trace "[elements_getnewaddress] label=${label}"

  local wallet=${3:-}
  trace "[getnewaddress] wallet=${wallet}"

  local response
  local returncode
  local address
  local data

  # label and address_type come from the request. Pass them to jq as data so
  # their contents can never change the JSON-RPC method or structure.
  data=$(jq -nc --arg addr_label "${label}" --arg address_type "${address_type}" '
    {method: "getnewaddress"}
    | if ($addr_label != "" or $address_type != "") then .params = {} else . end
    | if $addr_label != "" then .params.label = $addr_label else . end
    | if $address_type != "" then .params.address_type = $address_type else . end
  ')
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    return "${returncode}"
  fi
  trace "[elements_getnewaddress] data=${data}"

  if [ -n "${wallet}" ]; then
    response=$(send_to_elements_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_elements_spender_node "${data}")
  fi
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_getnewaddress] response=${response}"

  if [ "${returncode}" -ne 0 ]; then
    trace "[elements_getnewaddress] Coudn't get a new address!"
    echo "${response}"
    return "${returncode}"
  fi

  address=$(printf '%s\n' "${response}" | jq -er '.result | select(type == "string" and length > 0)')
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    echo "${response}"
    return "${returncode}"
  fi
  trace "[elements_getnewaddress] address=${address}"

  data=$(jq -nc --arg address "${address}" --arg addr_label "${label}" --arg address_type "${address_type}" '
    {address: $address}
    | if $addr_label != "" then .label = $addr_label else . end
    | if $address_type != "" then .address_type = $address_type else . end
  ')
  returncode=$?
  trace "[elements_getnewaddress] data=${data}"

  trace "[elements_getnewaddress] responding=${data}"
  echo "${data}"

  return "${returncode}"
}

elements_create_wallet() {
  trace "[Entering elements_create_wallet()]"

  local walletname=${1}

  local rpcstring
  rpcstring=$(jq -nc --arg walletname "${walletname}" '{method:"createwallet",params:[$walletname,true]}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  trace "[elements_create_wallet] rpcstring=${rpcstring}"

  local result
  result=$(send_to_elements_watcher_node "${rpcstring}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}

elements_getwalletinfo() {
  trace "Entering elements_getwalletinfo()..."

  local data='{"method":"getwalletinfo"}'
  local response
  local returncode
  response=$(send_to_elements_spender_node "${data}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    echo "${response}"
    return "${returncode}"
  fi
  echo "${response}" | jq ".result"
  return $?
}
