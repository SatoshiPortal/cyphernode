#!/bin/sh

blocknotify(){
  echo "[blocknotify-$$] Entering blocknotify"

  local blockhash="$@"
  echo "[blocknotify-$$] [blockhash=$blockhash]"

  local blockheight
  blockheight=$(get_block_height "$blockhash")

  echo "[blocknotify-$$] mosquitto_pub -h broker -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
  mosquitto_pub -h broker -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}"

  local chain_info
  chain_info=$(bitcoin-cli getblockchaininfo | jq -Mc)

  local chain_tip
  chain_tip=$(echo "$chain_info" | jq '.blocks')

  # Only send this new tip "bitcoin_node_newtip" to broker if it is the actual tip
  if [ "$blockheight" -ge "$chain_tip" ]; then
    echo "[blocknotify-$$] mosquitto_pub -h broker -t bitcoin_node_newtip -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
    mosquitto_pub -h broker -t bitcoin_node_newtip -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}"
  else
    echo "[blocknotify-$$] Skipping publication ["${blockheight}" < "${chain_tip}"] on topic bitcoin_node_newtip"
  fi

  echo "[blocknotify-$$] Done"
}

get_block_height(){
  local blockinfo
  blockinfo=$(bitcoin-cli getblock "$1")

  local blockheight
  blockheight=$(echo "${blockinfo}" | jq -r ".height")

  echo "$blockheight"
}

blocknotify "$@"
