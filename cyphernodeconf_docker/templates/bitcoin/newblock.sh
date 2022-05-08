#!/bin/sh

newblock(){
  echo "[newblock] Enering newblock"

  local blockhash="$@"
  echo "[newblock] [blockhash=$blockhash]"

  local blockheight
  blockheight=$(get_block_height $blockhash)

  echo "[newblock] mosquitto_pub -h broker -t newblock -m \"{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}\""
  mosquitto_pub -h broker -t newblock -m "{\"blockhash\":\"${blockhash}\",\"blockheight\":${blockheight}}"
}

get_block_height(){
  local blockinfo
  blockinfo=$(bitcoin-cli getblock $1)

  local blockheight
  blockheight=$(echo ${blockinfo} | jq -r ".height")

  echo $blockheight
}

newblock $@

echo "[newblock] Done"