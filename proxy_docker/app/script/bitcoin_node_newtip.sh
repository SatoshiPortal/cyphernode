#!/bin/sh

. ./trace.sh

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
  trace "[processNewTip] Entering processNewTip()..."

  (
  local returncode
  local flock_output
  
  flock_output=$(flock --verbose --nonblock 7 2>&1)
  returncode=$?
  trace "[processNewTip] flock_output=${flock_output}"

  if [ "$returncode" -eq "0" ]; then
    sh -c "./processnewtip.sh"
  else
    trace "[processNewTip] Exiting flock"
  fi
  ) 7>./.processnewtip.lock
}

bitcoin_node_newtip
returncode=$?
trace "[bitcoin_node_newtip] exiting"
exit ${returncode}