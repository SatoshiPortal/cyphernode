#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./blockchainrpc.sh
. ./batching.sh

newblock() {
  trace "Entering newblock()..."

  (
  local flock_output
  flock_output=$(flock --verbose --timeout 60 7)
  returncode=$?
  trace "[newblock] flock_output=${flock_output}"
  if [ "$returncode" -eq "0" ]; then
    local request=${1}
    local blockhash=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)

    local blockinfo
    blockinfo=$(get_block_info "${blockhash}")

    local blockheight
    blockheight=$(echo "${blockinfo}" | jq -r ".result.height")

    trace "[newblock] mosquitto_pub -h broker -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
    response=$(mosquitto_pub -h broker -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}")
    returncode=$?
    trace_rc ${returncode}

    # do_callbacks_txid "$(echo "${blockinfo}" | jq ".result.tx[]")"
    do_callbacks_txid
    batch_check_webhooks
  else
    trace "[newblock]  Exiting flock"
  fi
  ) 7>./.newblock.lock
}