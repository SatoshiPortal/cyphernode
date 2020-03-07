#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

get_best_block_hash() {
  trace "Entering get_best_block_hash()..."

  local data='{"method":"getbestblockhash"}'
  send_to_watcher_node "${data}"
  return $?
}

getestimatesmartfee() {
  trace "Entering getestimatesmartfee()..."

  local nb_blocks=${1}
  trace "[getestimatesmartfee] nb_blocks=${nb_blocks}"
  send_to_watcher_node "{\"method\":\"estimatesmartfee\",\"params\":[${nb_blocks}]}" | jq ".result.feerate" | awk '{ printf "%.8f", $0 }'
  return $?
}

get_block_info() {
  trace "Entering get_block_info()..."

  local block_hash=${1}
  trace "[get_block_info] block_hash=${block_hash}"
  local data="{\"method\":\"getblock\",\"params\":[\"${block_hash}\"]}"
  trace "[get_block_info] data=${data}"
  send_to_watcher_node "${data}"
  return $?
}

get_best_block_info() {
  trace "Entering get_best_block_info()..."

  local block_hash=$(echo "$(get_best_block_hash)" | jq -r ".result")
  trace "[get_best_block_info] block_hash=${block_hash}"
  get_block_info ${block_hash}
  return $?
}

get_rawtransaction() {
  trace "Entering get_rawtransaction()..."

  local txid=${1}
  trace "[get_rawtransaction] txid=${txid}"
  local data="{\"method\":\"getrawtransaction\",\"params\":[\"${txid}\",true]}"
  trace "[get_rawtransaction] data=${data}"
  send_to_watcher_node "${data}"
  return $?
}

get_transaction() {
  trace "Entering get_transaction()..."

  local txid=${1}
  trace "[get_transaction] txid=${txid}"
  local to_spender_node=${2}
  trace "[get_transaction] to_spender_node=${to_spender_node}"

  local data="{\"method\":\"gettransaction\",\"params\":[\"${txid}\",true]}"
  trace "[get_transaction] data=${data}"
  if [ -z "${to_spender_node}" ]; then
    send_to_watcher_node "${data}"
  else
    send_to_spender_node "${data}"
  fi
  return $?
}

get_blockchain_info() {
  trace "Entering get_blockchain_info()..."

  local data='{"method":"getblockchaininfo"}'
  send_to_watcher_node "${data}" | jq ".result"
  return $?
}

psbt_rescanblockchain() {
  trace "Entering rescanblockchain()..."

  local start_block=${1}
  trace "[rescanblockchain] start_block=${start_block}"
  local end_block=${2}
  trace "[rescanblockchain] end_block=${end_block}"

  local rpcstring="{\"method\":\"rescanblockchain\",\"params\":[${start_block},${end_block}]}"
  trace "[rescanblockchain] rpcstring=${rpcstring}"
  send_to_psbt_wallet "${rpcstring}"
  return $?
}

psbt_abort_rescanblockchain() {
  trace "Entering psbt_abort_rescanblockchain()..."

  local rpcstring="{\"method\":\"abortrescan\"}"
  trace "[psbt_cancel_rescanblockchain] rpcstring=${rpcstring}"
  send_to_psbt_wallet "${rpcstring}"
  return $?
}

get_blockcount() {
  trace "Entering get_blockcount()..."

  local data='{"method":"getblockcount"}'
  send_to_watcher_node "${data}" | jq ".result"
  return $?
}

get_mempool_info() {
  trace "Entering get_mempool_info()..."

  local data='{"method":"getmempoolinfo"}'
  send_to_watcher_node "${data}" | jq ".result"
  return $?
}
get_blockhash() {
  trace "Entering get_blockhash()..."
  local blockheight=${1}
  local data="{\"method\":\"getblockhash\",\"params\":[${blockheight}]}"
  send_to_watcher_node "${data}" | jq ".result"
  return $?
}

sendrawtransaction() {
  trace "Entering sendrawtransaction()..."
  local rawtxhex=${1}
  local result
  trace "[sendrawtransaction] rawtxhex=${rawtxhex}"
  result=send_to_spender_node "{\"method\":\"sendrawtransaction\",\"params\":[\"${rawtxhex}\"]}"
  trace "[sendrawtransaction] result=${result}"
  echo "$result"
  return $?
}
