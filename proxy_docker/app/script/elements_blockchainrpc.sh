#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh
. ./elements_walletoperations.sh

elements_get_best_block_hash() {
  trace "Entering elements_get_best_block_hash()..."

  local data='{"method":"getbestblockhash"}'
  send_to_elements_watcher_node "${data}"
  return $?
}

elements_get_block_info() {
  trace "Entering elements_get_block_info()..."

  local block_hash=${1}
  trace "[elements_get_block_info] block_hash=${block_hash}"
  local data
  data=$(jq -nc --arg block_hash "${block_hash}" '{method:"getblock",params:[$block_hash]}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  trace "[elements_get_block_info] data=${data}"
  send_to_elements_watcher_node "${data}"
  return $?
}

elements_get_best_block_info() {
  trace "Entering elements_get_best_block_info()..."

  local block_hash=$(echo "$(elements_get_best_block_hash)" | jq -r ".result")
  trace "[elements_get_best_block_info] block_hash=${block_hash}"
  elements_get_block_info "${block_hash}"
  return $?
}

elements_get_rawtransaction() {
  trace "Entering elements_get_rawtransaction()..."

  local txid=${1}
  trace "[elements_get_rawtransaction] txid=${txid}"
  local to_elements_spender_node=${2}
  trace "[elements_get_transaction] to_elements_spender_node=${to_elements_spender_node}"

  local data
  data=$(jq -nc --arg txid "${txid}" '{method:"getrawtransaction",params:[$txid,true]}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  trace "[elements_get_rawtransaction] data=${data}"
  if [ -z "${to_elements_spender_node}" ]; then
    send_to_elements_watcher_node "${data}"
  else
    send_to_elements_spender_node "${data}"
  fi
  return $?
}

elements_get_transaction() {
  trace "Entering elements_get_transaction()..."

  local txid=${1}
  trace "[elements_get_transaction] txid=${txid}"
  local to_elements_spender_node=${2}
  trace "[elements_get_transaction] to_elements_spender_node=${to_elements_spender_node}"
  local wallet=${3}
  trace "[get_transaction] wallet=${wallet}"

  local data
  data=$(jq -nc --arg txid "${txid}" '{method:"gettransaction",params:[$txid,true]}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  trace "[elements_get_transaction] data=${data}"
  if [ -z "${to_elements_spender_node}" ]; then
    send_to_elements_watcher_node "${data}"
  elif [ -n "${wallet}" ]; then
    send_to_elements_spender_node "${data}" "${wallet}"
  else
    send_to_elements_spender_node "${data}"
  fi
  return $?
}

elements_get_blockchain_info() {
  trace "Entering elements_get_blockchain_info()..."

  local data='{"method":"getblockchaininfo"}'
  local response
  local returncode
  response=$(send_to_elements_watcher_node "${data}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    echo "${response}"
    return "${returncode}"
  fi
  echo "${response}" | jq ".result"
  return $?
}

elements_get_mempool_info() {
  trace "Entering elements_get_mempool_info()..."

  local data='{"method":"getmempoolinfo"}'
  local response
  local returncode
  response=$(send_to_elements_watcher_node "${data}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    echo "${response}"
    return "${returncode}"
  fi
  echo "${response}" | jq ".result"
  return $?
}

elements_get_blockhash() {
  trace "Entering elements_get_blockhash()..."
  local blockheight=${1}
  local data
  data=$(jq -nc --argjson block_height "${blockheight}" '{method:"getblockhash",params:[$block_height]}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  local response
  response=$(send_to_elements_watcher_node "${data}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    echo "${response}"
    return "${returncode}"
  fi
  echo "${response}" | jq ".result"
  return $?
}

elements_validateaddress() {
  trace "Entering elements_validateaddress()..."

  local address=${1}
  trace "[elements_validateaddress] address=${address}"
  local data
  data=$(jq -nc --arg address "${address}" '{method:"validateaddress",params:[$address]}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  trace "[elements_validateaddress] data=${data}"
  send_to_elements_watcher_node "${data}"
  return $?
}

elements_generatetoaddress() {
  trace "Entering elements_generatetoaddress()..."

  local nbblocks=$(echo "${1}" | jq '.nbblocks // 1') # Optional - Default 1
  local address=$(echo "${1}" | jq -r '.address // empty') # Optional - getnewadress from spender wallet
  local maxtries=$(echo "${1}" | jq '.maxtries // 1000000')  # Optional - use Core default

  if [ -z "${address}" ]; then
    address=$(elements_getnewaddress | jq -r '.address')
  fi

  trace "[elements_generatetoaddress] nbblocks=[${nbblocks}] address=[${address}] maxtries=[${maxtries}]"

  local data
  data=$(jq -nc --argjson nbblocks "${nbblocks}" --arg address "${address}" --argjson maxtries "${maxtries}" \
    '{method:"generatetoaddress",params:[$nbblocks,$address,$maxtries]}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"

  trace "[elements_generatetoaddress] data=${data}"

  send_to_elements_spender_node "${data}"
  return $?
}

# example curl -m 20 -s --config /tmp/watcher_elementsnode_curlcfg.properties -H "Content-Type: text/plain"
#    --data-binary '{"method":"gettxoutproof","params":[["3bdb32c04e10b6c399bd3657ef8b0300649189e90d7cb
#           79c4f997dea8fb532cb"],"0000000000000000007962066dcd6675830883516bcf40047d42740a85eb2919"] }'
#           elements:7041/wallet/watching01.dat
elements_gettxoutproof() {
  trace "Entering elements_gettxoutproof()..."

  local txids=${1}
  local blockhash=${2}
  local txids_json
  local data
  local returncode

  txids_json=$(echo "${txids}" | jq -Mc 'select(type == "array")')
  returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"

  # The blockhash is optional
  if [ -z "${2}" ]; then
    data=$(jq -nc --argjson txids "${txids_json}" '{method:"gettxoutproof",params:[$txids]}')
  else
    data=$(jq -nc --argjson txids "${txids_json}" --arg blockhash "${blockhash}" '{method:"gettxoutproof",params:[$txids,$blockhash]}')
  fi
  returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"

  trace "[elements_gettxoutproof] txids=${txids}"
  trace "[elements_gettxoutproof] blockhash=${blockhash}"

  trace "[elements_gettxoutproof] data=${data}"

  send_to_elements_watcher_node "${data}"

  return $?
}

elements_getaddressinfo() {
  trace "Entering elements_get_addressinfo()..."

  local address=${1}
  trace "[elements_get_addressinfo] address=${address}"
  local to_elements_spender_node=${2}
  trace "[elements_get_addressinfo] to_elements_spender_node=${to_elements_spender_node}"
  local wallet=${3}
  if [ -n "${wallet}" ]; then
    trace "[elements_get_addressinfo] wallet=${wallet}"
  fi

  local data
  data=$(jq -nc --arg address "${address}" '{method:"getaddressinfo",params:[$address]}')
  trace "[elements_get_addressinfo] data=${data}"
  if [ -z "${to_elements_spender_node}" ]; then
    send_to_elements_watcher_node "${data}"
  elif [ -n "${wallet}" ]; then
    send_to_elements_spender_node "${data}" "${wallet}"
  else
    send_to_elements_spender_node "${data}"
  fi
  return $?
}
