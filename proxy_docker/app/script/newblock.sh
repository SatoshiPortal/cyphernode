#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh

newblock() {
  trace "Entering newblock()..."

  local request=${1}
  local blockhash=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)

  do_callbacks_txid
}
