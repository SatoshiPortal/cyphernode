#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./blockchainrpc.sh
. ./batching.sh

newblock() {
  (
  flock --verbose -x 7

  trace "Entering newblock()..."

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

  ) 7>./.newblock.lock
}
