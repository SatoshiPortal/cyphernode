#!/bin/bash

MEASURMENT=fees

feescollected() {
  local cmd="/usr/bin/lightning-cli getinfo"
  $cmd  | jq '.msatoshi_fees_collected'
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
