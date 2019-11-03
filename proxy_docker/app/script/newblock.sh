#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./blockchainrpc.sh

newblock() {
  trace "Entering newblock()..."

  local request=${1}
  local blockhash=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)

  local blockinfo
  blockinfo=$(get_block_info ${blockhash})

  local blockheight
  blockheight=$(echo ${blockinfo} | jq -r ".result.height")

  trace "[newblock] mosquitto_pub -h broker -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
  response=$(mosquitto_pub -h broker -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}")
  returncode=$?
  trace_rc ${returncode}

  do_callbacks_txid
  if [ "$(( $(od -An -N2 < /dev/urandom) % 5 ))" = "0" ]; then
    trace "[newBlock] Let's try to spend mixed coins!"
    wasabi_batchprivatetospender
  else
    trace "[newblock] We won't try to spend mixed coins now, relax."
  fi
}
