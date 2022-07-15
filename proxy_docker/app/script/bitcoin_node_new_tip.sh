#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./batching.sh

bitcoin_node_new_tip() {
  trace "Entering bitcoin_node_new_tip()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t bitcoin_node_new_tip | while read -r message
    do
      trace "[bitcoin_node_new_tip] Message: ${message}"
      processNewTip "${message}"
      trace "[bitcoin_node_new_tip] Done processing"
    done

    trace "[bitcoin_node_new_tip] reconnecting in 10 secs" 
    sleep 10
  done
}

processNewTip(){
  (
  flock -x 7

  trace "[bitcoin_node_new_tip] Entering processNewTip()..."

  do_callbacks_txid
  batch_check_webhooks

  ) 7>./.processnewtip.lock
}

bitcoin_node_new_tip
returncode=$?
trace "[bitcoin_node_new_tip] exiting"
exit ${returncode}