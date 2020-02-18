#!/bin/sh

. ./trace.sh
. ./elements_callbacks_txid.sh
. ./elements_blockchainrpc.sh

elements_newblock() {
  trace "Entering elements_newblock()..."

  local request=${1}
  local blockhash=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)

  local blockinfo
  blockinfo=$(elements_get_block_info ${blockhash})

  local blockheight
  blockheight=$(echo ${blockinfo} | jq -r ".result.height")

  trace "[elements_newblock] mosquitto_pub -h broker -t elements_newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":\"${blockheight}\"}\""
  response=$(mosquitto_pub -h broker -t elements_newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":\"${blockheight}\"}")
  returncode=$?
  trace_rc ${returncode}

  elements_do_callbacks_txid
}
