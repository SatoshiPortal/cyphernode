#!/bin/sh

. ./trace.sh

bitcoin_node_walletnotify() {
  trace "Entering bitcoin_node_walletnotify()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    mosquitto_sub -h broker -t cyphernode/bitcoin/walletnotify | while read -r message
    do
      trace "[bitcoin_node_walletnotify] Processing cyphernode/bitcoin/walletnotify from bitcoin node"
      ./confirmation.sh "${message}"

      # Forward to sp_docker for SP watch notifications.
      if [ -n "${SP_HOST}" ]; then
        local payload
        payload=$(jq -cn --arg d "${message}" '{"data": $d}')
        curl -sS -m 5 -H 'content-type: application/json' \
          --data-binary "${payload}" "${SP_HOST}/notify_tx" > /dev/null 2>&1 || true
      fi
    done

    trace "[bitcoin_node_walletnotify] reconnecting in 10 secs"
    sleep 10
  done
}

bitcoin_node_walletnotify
returncode=$?
trace "[bitcoin_node_walletnotify] exiting"
exit ${returncode}
