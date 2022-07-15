#!/bin/bash

# This needs to be run in regtest

# This will mine n blocks.  If n is not supplied, will mine 1 block.

# Mine
mine() {
  local nbblocks=${1:-1}

  echo ; echo "About to mine ${nbblocks} block(s)..."
  docker exec -t $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat -generate ${nbblocks}
}

case "${0}" in *mine.sh) mine "$@";; esac
