#!/bin/sh

. ./trace.sh
. ./confirmation.sh

bitcoin_node_conf() {
  trace "Entering bitcoin_node_conf()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t confirmation | while read -r message
    do
      trace "[bitcoin_node_conf] Processing confirmation from bitcoin node" 
      confirmation ${message}
    done

    trace "[bitcoin_node_conf] reconnecting in 10 secs" 
    sleep 10
  done
}

bitcoin_node_conf
returncode=$?
trace "[bitcoin_node_conf] exiting"
exit ${returncode}