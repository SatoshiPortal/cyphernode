#!/bin/sh

. ./trace.sh
. ./elements_callbacks_txid.sh

elements_processnewtip() {
  trace "[elements_processnewtip] Entering elements_processnewtip()..."
  
  elements_do_callbacks_txid
}

case "${0}" in *elements_processnewtip.sh) elements_processnewtip "$@";; esac
