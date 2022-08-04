#!/bin/sh

. ./trace.sh
. ./callbacks_txid.sh
. ./batching.sh

processnewtip() {
  trace "[processnewtip] Entering processnewtip()..."
  
  do_callbacks_txid
  batch_check_webhooks
}

case "${0}" in *processnewtip.sh) processnewtip "$@";; esac
