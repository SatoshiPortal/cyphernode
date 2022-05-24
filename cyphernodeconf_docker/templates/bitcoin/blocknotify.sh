#!/bin/sh

blocknotify(){
  local pid=$(cut -d' ' -f4 < /proc/self/stat)

  echo "[blocknotify-$pid] Entering blocknotify"

  local blockhash="$@"
  echo "[blocknotify-$pid] [blockhash=$blockhash]"

  local blockheight
  blockheight=$(get_block_height $blockhash)

  echo "[blocknotify-$pid] mosquitto_pub -h broker --retain -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
  mosquitto_pub -h broker --retain -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}"

  echo "[blocknotify-$pid] Done"
}

get_block_height(){
  local blockinfo
  blockinfo=$(bitcoin-cli getblock $1)

  local blockheight
  blockheight=$(echo ${blockinfo} | jq -r ".height")

  echo $blockheight
}

blocknotify $@
