#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh
. ./walletoperations.sh

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

validateaddress() {
  trace "Entering validateaddress()..."

  local address=${1}
  trace "[validateaddress] address=${address}"
  local data="{\"method\":\"validateaddress\",\"params\":[\"${address}\"]}"
  trace "[validateaddress] data=${data}"
  send_to_watcher_node "${data}"
  return $?
}

bitcoin_estimatesmartfee() {
  trace "Entering bitcoin_estimatesmartfee()..."

  local conf_target=${1}
  trace "[bitcoin_estimatesmartfee] conf_target=${conf_target}"
  local data="{\"method\":\"estimatesmartfee\",\"params\":[${conf_target}]}"
  trace "[bitcoin_estimatesmartfee] data=${data}"
  send_to_watcher_node "${data}"
  return $?
}

bitcoin_generatetoaddress() {
  trace "Entering bitcoin_generatetoaddress()..."

  local nbblocks=$(echo ${1} | jq '.nbblocks // 1') # Optional - Default 1
  local address=$(echo ${1} | jq '.address // empty') # Optional - getnewadress from spender wallet
  local maxtries=$(echo ${1} | jq '.maxtries // 1000000')  # Optional - use Core default
                    
  if [ -z "${address}" ]; then          
    address=$(getnewaddress | jq '.address')
  fi   

  trace "[bitcoin_generatetoaddress] nbblocks=[${nbblocks}] address=[${address}] maxtries=[${maxtries}]"

  local data
  data="{\"method\":\"generatetoaddress\",\"params\":[${nbblocks},${address},${maxtries}]}"

  trace "[bitcoin_bitcoin_generatetoaddress] data=${data}"

  send_to_spender_node "${data}"
  return $?
}

# example curl -m 20 -s --config /tmp/watcher_btcnode_curlcfg.properties -H "Content-Type: text/plain"
#    --data-binary '{"method":"gettxoutproof","params":[["3bdb32c04e10b6c399bd3657ef8b0300649189e90d7cb
#           79c4f997dea8fb532cb"],"0000000000000000007962066dcd6675830883516bcf40047d42740a85eb2919"] }' 
#           bitcoin:18443/wallet/watching01.dat
bitcoin_gettxoutproof() {
  trace "Entering bitcoin_gettxoutproof()..."

  local txids=${1}
  local blockhash=${2}
  local params

  # The blockhash is optional
  if [ -z "${2}" ]; then
    params=${1}
  else
    params="${1},\"${2}\""
  fi

  trace "[bitcoin_gettxoutproof] txids=${txids}"
  trace "[bitcoin_gettxoutproof] blockhash=${blockhash}"

  trace "[bitcoin_gettxoutproof] params=${params}"

  local data="{\"method\":\"gettxoutproof\",\"params\":[${params}]}"
  trace "[bitcoin_gettxoutproof] data=${data}"

  send_to_watcher_node "${data}"

  return $?
}
