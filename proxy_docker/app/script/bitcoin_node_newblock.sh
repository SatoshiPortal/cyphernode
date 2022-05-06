#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./blockchainrpc.sh
. ./batching.sh

bitcoin_node_newblock() {

  trace "Entering bitcoin_node_newblock()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t bitcoin_node_newblock | while read -r blockhash
    do
      trace "[bitcoin_node_newblock] Blockhash: ${blockhash}"
      processNewBlock ${blockhash}
    done

    trace "[bitcoin_node_newblock] reconnecting in 10 secs" 
    sleep 10
  done
}

processNewBlock(){
  (
  flock -x 202

  trace "[bitcoin_node_newblock] Entering processNewblock()..."

  local blockinfo
  blockinfo=$(get_block_info $1)

  local blockheight
  blockheight=$(echo ${blockinfo} | jq -r ".result.height")

  trace "[bitcoin_node_newblock] mosquitto_pub -h broker -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
  response=$(mosquitto_pub -h broker -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}")
  returncode=$?
  trace_rc ${returncode}

  # do_callbacks_txid "$(echo "${blockinfo}" | jq ".result.tx[]")"
  do_callbacks_txid
  batch_check_webhooks

  ) 202>./.processnewblock.lock
}

bitcoin_node_newblock
returncode=$?
trace "[bitcoin_node_newblock] exiting"
exit ${returncode}