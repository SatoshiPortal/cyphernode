#!/bin/sh

. ./trace.sh
. ./confirmation.sh

bitcoin_node_walletnotify() {
  trace "Entering bitcoin_node_walletnotify()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t bitcoin_watching_walletnotify | while read -r message
    do
      trace "[bitcoin_node_walletnotify] Processing bitcoin_watching_walletnotify from bitcoin node"
      confirmation "${message}"
    done

    trace "[bitcoin_node_walletnotify] reconnecting in 10 secs"
    sleep 10
  done
}

bitcoin_node_walletnotify
returncode=$?
trace "[bitcoin_node_walletnotify] exiting"
exit ${returncode}
