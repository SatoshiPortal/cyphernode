#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./batching.sh

bitcoin_node_newblock() {

  trace "Entering bitcoin_node_newblock()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t newblock | while read -r message
    do
      trace "[bitcoin_node_newblock] Message: ${message}"
      processNewBlock ${message}
    done

    trace "[bitcoin_node_newblock] reconnecting in 10 secs" 
    sleep 10
  done
}

processNewBlock(){
  (
  flock -x 202

  trace "[bitcoin_node_newblock] Entering processNewblock()..."

  do_callbacks_txid
  batch_check_webhooks

  ) 202>./.processnewblock.lock
}

bitcoin_node_newblock
returncode=$?
trace "[bitcoin_node_newblock] exiting"
exit ${returncode}