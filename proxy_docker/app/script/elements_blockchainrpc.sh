#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

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
