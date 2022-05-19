#!/bin/sh

newblock(){
  local pid=$(cut -d' ' -f4 < /proc/self/stat)

  echo "[newblock-$pid] Entering newblock"

  local blockhash="$@"
  echo "[newblock-$pid] [blockhash=$blockhash]"

  local blockheight
  blockheight=$(get_block_height $blockhash)

  echo "[newblock-$pid] mosquitto_pub -h broker --retain -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
  mosquitto_pub -h broker --retain -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}"

  echo "[newblock-$pid] Done"
}

get_block_height(){
  local blockinfo
  blockinfo=$(bitcoin-cli getblock $1)

  local blockheight
  blockheight=$(echo ${blockinfo} | jq -r ".height")

  echo $blockheight
}

newblock $@
