#!/bin/sh

. ./trace.sh

bitcoin_node_newtip() {
  trace "Entering bitcoin_node_newtip()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    # Force client to disconnect after receving a message.  Otherwise the client will exit when it receives the first
    # fresh / non-stale message
    message=$(mosquitto_sub -h broker -t cyphernode/bitcoin/newtip --retained-only --remove-retained -W 1 2>/dev/null)

    if [ -n "${message}" ]; then
      trace "[bitcoin_node_newtip] Message: ${message}"
      processNewTip "${message}"
      trace "[bitcoin_node_newtip] Done processing"
    fi

    trace "[bitcoin_node_newtip] reconnecting in 60 secs"
    sleep 60
  done
}

processNewTip(){
  trace "[processNewTip] Entering processNewTip()..."

  (
  local returncode
  local flock_output

  flock_output=$(flock --verbose --nonblock 7 2>&1)
  returncode=$?
  trace "[processNewTip] flock_output=${flock_output}"

  if [ "$returncode" -eq "0" ]; then
    ./processnewtip.sh
  else
    trace "[processNewTip] Exiting flock"
  fi
  ) 7>./.processnewtip.lock
}

bitcoin_node_newtip
returncode=$?
trace "[bitcoin_node_newtip] exiting"
exit ${returncode}