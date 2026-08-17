#!/bin/sh

. ./trace.sh

elements_node_newtip() {
  trace "Entering elements_node_newtip()..."

  while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
  do
    # Force client to disconnect after receving a message.  Otherwise the client will exit when it receives the first
    # fresh / non-stale message
    message=$(mosquitto_sub -h broker -t cyphernode/elements/newtip --retained-only --remove-retained -W 1 2>/dev/null)

    if [ -n "${message}" ]; then
      trace "[elements_node_newtip] Message: ${message}"
      elements_processNewTip "${message}"
      trace "[elements_node_newtip] Done processing"
    fi

    trace "[elements_node_newtip] reconnecting in 60 secs"
    sleep 60
  done
}

elements_processNewTip(){
  trace "[elements_processNewTip] Entering elements_processNewTip()..."

  (
  local returncode
  local flock_output

  flock_output=$(flock --verbose --nonblock 7 2>&1)
  returncode=$?
  trace "[elements_processNewTip] flock_output=${flock_output}"

  if [ "$returncode" -eq "0" ]; then
    ./elements_processnewtip.sh
  else
    trace "[elements_processNewTip] Exiting flock"
  fi
  ) 7>./.elementsprocessnewtip.lock
}

elements_node_newtip
returncode=$?
trace "[elements_node_newtip] exiting"
exit ${returncode}