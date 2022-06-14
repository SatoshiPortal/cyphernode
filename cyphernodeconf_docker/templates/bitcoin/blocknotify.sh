#!/bin/sh

blocknotify(){
  echo "[blocknotify-$$] Entering blocknotify"

  local blockhash="$@"
  echo "[blocknotify-$$] [blockhash=$blockhash]"

  local blockheight
  blockheight=$(get_block_height $blockhash)

  echo "[blocknotify-$$] mosquitto_pub -h broker --retain -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
  mosquitto_pub -h broker --retain -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}"

  echo "[blocknotify-$$] Done"
}

get_block_height(){
  local blockinfo
  blockinfo=$(bitcoin-cli getblock $1)

  local blockheight
  blockheight=$(echo ${blockinfo} | jq -r ".height")

  echo $blockheight
}

blocknotify $@
