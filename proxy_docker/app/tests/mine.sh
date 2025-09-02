#!/bin/bash

# This needs to be run in regtest

# This will mine n blocks.  If n is not supplied, will mine 1 block.

# Mine
mine() {
  local nbblocks=${1:-1}

  echo ; echo "About to mine ${nbblocks} block(s)..."
  docker exec -t $(docker ps -q -f "name=cyphernode_bitcoin$2\.") bitcoin-cli -rpcwallet=spending01.dat -generate ${nbblocks}
}

elements_mine() {
  local nbblocks=${1:-1}

  echo ; echo "About to mine ${nbblocks} block(s)..."
  docker exec -t $(docker ps -q -f "name=cyphernode_elements") elements-cli -rpcwallet=spending01.dat -generate ${nbblocks}
}

case "${1}" in
  elements) shift; elements_mine $@;;
  bitcoin) shift; mine $@;;
esac
