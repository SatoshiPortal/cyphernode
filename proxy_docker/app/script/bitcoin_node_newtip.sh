#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./batching.sh

bitcoin_node_newtip() {
  trace "Entering bitcoin_node_newtip()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t bitcoin_node_newtip | while read -r message
    do
      trace "[bitcoin_node_newtip] Message: ${message}"
      processNewTip "${message}"
      trace "[bitcoin_node_newtip] Done processing"
    done

    trace "[bitcoin_node_newtip] reconnecting in 10 secs" 
    sleep 10
  done
}

processNewTip(){
  (
  flock -x 7

  trace "[bitcoin_node_newtip] Entering processNewTip()..."

  do_callbacks_txid
  batch_check_webhooks

  ) 7>./.processnewtip.lock
}

bitcoin_node_newtip
returncode=$?
trace "[bitcoin_node_newtip] exiting"
exit ${returncode}