#!/bin/sh

. ./trace.sh
. ./elements_callbacks_txid.sh
. ./elements_blockchainrpc.sh

elements_newblock() {
  trace "Entering elements_newblock()..."

  local request=${1}
  local blockhash=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)

  trace "[elements_newblock] mosquitto_pub -h broker -t elements_newblock -m \"{\"blockhash\":\"${blockhash}\"}\""
  response=$(mosquitto_pub -h broker -t elements_newblock -m "{\"blockhash\":\"${blockhash}\"}")
  returncode=$?
  trace_rc ${returncode}

  # This seems to be called in some cases when catching up syncing and was flooding Cyphernode,
  # so since blocks on Liquid are pretty fast anyway and there's no mempool overflow, we can skip
  # blocks before checking for callbacks.
  if [ "$(( $(od -An -N2 < /dev/urandom) % 5 ))" = "0" ]; then
    trace "[elements_newblock] Let's see if we have webhooks to call"
    elements_do_callbacks_txid
  fi
}
