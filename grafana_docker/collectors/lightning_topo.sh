#!/bin/bash

MEASURMENT=topo

calculate_network_value() {
  local json=$1
  local msatoshis=$( echo "$json" | jq '.channels[] | select(.state == "CHANNELD_NORMAL" )' | jq -s 'map(.msatoshi_total) | add')
  echo "$msatoshis 100000000000" | awk '{printf "%0.8f", $1 / $2}'
}

get_channel_count() {
  local json=$1
  echo "$json" | jq '.channels | length'
}

get_node_count() {
  local cmd="/usr/bin/lightning-cli listnodes"
  $cmd  | jq '.nodes | length'
}

query_lightning_node() {
  local network_value=0
  local channel_count=0
  local node_count=0

  local v

  local listchannels_result=$(/usr/bin/lightning-cli listchannels)

  v=$(calculate_network_value "$listchannels_result")
  if [[ $v ]]; then
      network_value=$v
  fi

  v=$(get_channel_count "$listchannels_result")
  if [[ $v ]]; then
      channel_count=$v
  fi

  v=$(get_node_count)
  if [[ $v ]]; then
      node_count=$v
  fi

  # write out influx line protocol
  # measurement,taglist(tag=value,tag=value) fieldlist(field=value,field=value) (timestamp[optional])
  echo -e ${MEASURMENT} node_count=${node_count}i,channel_count=${channel_count}i,network_value_btc=${network_value}

}

query_lightning_node

