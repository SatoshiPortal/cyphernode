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

elements_getestimatesmartfee() { ## TODO: Check if this endpoint exists and do we really want it here?
  trace "Entering elements_getestimatesmartfee()..."

  local nb_blocks=${1}
  trace "[elements_getestimatesmartfee] nb_blocks=${nb_blocks}"
  send_to_elements_watcher_node "{\"method\":\"estimatesmartfee\",\"params\":[${nb_blocks}]}" | jq ".result.feerate" | awk '{ printf "%.8f", $0 }'
  return $?
}

elements_get_block_info() {
  trace "Entering elements_get_block_info()..."

  local block_hash=${1}
  trace "[elements_get_block_info] block_hash=${block_hash}"
  local data="{\"method\":\"getblock\",\"params\":[\"${block_hash}\"]}"
  trace "[elements_get_block_info] data=${data}"
  send_to_elements_watcher_node "${data}"
  return $?
}

elements_get_best_block_info() {
  trace "Entering elements_get_best_block_info()..."

  local block_hash=$(echo "$(elements_get_best_block_hash)" | jq -r ".result")
  trace "[elements_get_best_block_info] block_hash=${block_hash}"
  elements_get_block_info ${block_hash}
  return $?
}

elements_get_rawtransaction() {
  trace "Entering elements_get_rawtransaction()..."

  local txid=${1}
  trace "[elements_get_rawtransaction] txid=${txid}"
  local to_elements_spender_node=${2}
  trace "[elements_get_transaction] to_elements_spender_node=${to_elements_spender_node}"

  local data="{\"method\":\"getrawtransaction\",\"params\":[\"${txid}\",true]}"
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

  local data="{\"method\":\"gettransaction\",\"params\":[\"${txid}\",true]}"
  trace "[elements_get_transaction] data=${data}"
  if [ -z "${to_elements_spender_node}" ]; then
    send_to_elements_watcher_node "${data}"
  else
    send_to_elements_spender_node "${data}"
  fi
  return $?
}

elements_get_blockchain_info() {
  trace "Entering elements_get_blockchain_info()..."

  local data='{"method":"getblockchaininfo"}'
  send_to_elements_watcher_node "${data}" | jq ".result"
  return $?
}

elements_get_mempool_info() {
  trace "Entering elements_get_mempool_info()..."

  local data='{"method":"getmempoolinfo"}'
  send_to_elements_watcher_node "${data}" | jq ".result"
  return $?
}

elements_get_blockhash() {
  trace "Entering elements_get_blockhash()..."
  local blockheight=${1}
  local data="{\"method\":\"getblockhash\",\"params\":[${blockheight}]}"
  send_to_elements_watcher_node "${data}" | jq ".result"
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

elements_estimatesmartfee() {
  trace "Entering elements_estimatesmartfee()..."

  local conf_target=${1}
  trace "[elements_estimatesmartfee] conf_target=${conf_target}"
  local data="{\"method\":\"estimatesmartfee\",\"params\":[${conf_target}]}"
  trace "[elements_estimatesmartfee] data=${data}"
  send_to_elements_watcher_node "${data}"
  return $?
}

elements_generatetoaddress() {
  trace "Entering elements_generatetoaddress()..."

  local nbblocks=$(echo ${1} | jq '.nbblocks // 1') # Optional - Default 1
  local address=$(echo ${1} | jq '.address // empty') # Optional - getnewadress from spender wallet
  local maxtries=$(echo ${1} | jq '.maxtries // 1000000')  # Optional - use Core default

  if [ -z "${address}" ]; then
    address=$(elements_getnewaddress | jq '.address')
  fi

  trace "[elements_generatetoaddress] nbblocks=[${nbblocks}] address=[${address}] maxtries=[${maxtries}]"

  local data
  data="{\"method\":\"generatetoaddress\",\"params\":[${nbblocks},${address},${maxtries}]}"

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
  local params

  # The blockhash is optional
  if [ -z "${2}" ]; then
    params=${1}
  else
    params="${1},\"${2}\""
  fi

  trace "[elements_gettxoutproof] txids=${txids}"
  trace "[elements_gettxoutproof] blockhash=${blockhash}"

  trace "[elements_gettxoutproof] params=${params}"

  local data="{\"method\":\"gettxoutproof\",\"params\":[${params}]}"
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

  local data="{\"method\":\"getaddressinfo\",\"params\":[\"${address}\"]}"
  trace "[elements_get_addressinfo] data=${data}"
  if [ -z "${to_elements_spender_node}" ]; then
    send_to_elements_watcher_node "${data}"
  else
    send_to_elements_spender_node "${data}"
  fi
  return $?
}
