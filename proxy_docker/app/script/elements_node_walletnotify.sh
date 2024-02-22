#!/bin/sh

. ./trace.sh

elements_node_walletnotify() {
  trace "Entering elements_node_walletnotify()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t cyphernode/elements/walletnotify | while read -r message
    do
      trace "[elements_node_walletnotify] Processing cyphernode/elements/walletnotify from elements node"
      ./elements_confirmation.sh "${message}"
    done

    trace "[elements_node_walletnotify] reconnecting in 10 secs"
    sleep 10
  done
}

elements_node_walletnotify
returncode=$?
trace "[elements_node_walletnotify] exiting"
exit ${returncode}
