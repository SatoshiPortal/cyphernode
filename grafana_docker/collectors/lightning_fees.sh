#!/bin/bash

MEASURMENT=fees

feescollected() {
  local cmd="/usr/bin/lightning-cli getinfo"
#  local cmd='echo {
#    "id": "02767db799d416d1c887de57acd23da7e6ab89a237ed2db0d28ef2153f1d46aa10",
#    "alias": "🚀 Nimble Nightingale 🚀",
#    "color": "00ff00",
#    "address": [
#    ],
#    "binding": [
#      {
#        "type": "ipv6",
#        "address": "::",
#        "port": 9735
#      },
#      {
#        "type": "ipv4",
#        "address": "0.0.0.0",
#        "port": 9735
#      }
#    ],
#    "version": "v0.6.2",
#    "blockheight": 3024,
#    "network": "testnet",
#    "msatoshi_fees_collected": 100
#  }'
#  $cmd  | jq '.msatoshi_fees_collected'
}

query_lightning_node() {
  local fees_collected=0

  local v

  v=$(feescollected)
  if [[ $v ]]; then
      fees_collected=$v
  fi

  # write out influx line protocol
  # measurement,taglist(tag=value,tag=value) fieldlist(field=value,field=value) (timestamp[optional])
  echo -e ${MEASURMENT} fees_collected=${fees_collected}i

}

query_lightning_node
