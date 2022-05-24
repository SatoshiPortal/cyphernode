#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./batching.sh

bitcoin_node_blocknotify() {
  local blockheight
  local newblockheight

  trace "Entering bitcoin_node_blocknotify()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    trace "[bitcoin_node_blocknotify] mosquitto_sub --retained-only -h broker -t newblock -C 1 -W 5"
    message=$(mosquitto_sub --retained-only -h broker -t newblock -C 1 -W 5) 
    trace "[bitcoin_node_blocknotify] Message: ${message}"

    newblockheight=$(echo $message | jq .blockheight)
    if [ -n "$newblockheight" ] && [ "$newblockheight" != "$blockheight" ]; then
      processNewBlock ${message}
      blockheight=$newblockheight
      trace "[bitcoin_node_blocknotify] Done processing"
    fi
    trace "[bitcoin_node_blocknotify] reconnecting in 60 secs" 
    sleep 60
  done
}

processNewBlock(){
  (
  flock -x 202

  trace "[bitcoin_node_blocknotify] Entering processNewblock()..."

  do_callbacks_txid
  batch_check_webhooks

  ) 202>./.processnewblock.lock
}

bitcoin_node_blocknotify
returncode=$?
trace "[bitcoin_node_blocknotify] exiting"
exit ${returncode}