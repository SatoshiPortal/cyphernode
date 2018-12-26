#!/bin/bash

MEASURMENT=counts

count_key_in_command() {
  local cmd=$1
  local key=$2
  ${cmd} | jq "${key} | length"
}

countforwards() {
  local cmd="/usr/bin/lightning-cli listforwards"
  #local cmd="echo -e { \"forwards\": [{},{}]}"
  local key='.forwards'
  count_key_in_command "$cmd" "$key"
}

countpeers() {
  local cmd="/usr/bin/lightning-cli listpeers"
  #local cmd="echo -e { \"peers\": [{},{}]}"
  local key='.peers'
  count_key_in_command "$cmd" "$key"
}

countpayments() {
  local cmd="/usr/bin/lightning-cli listpayments"
  #local cmd="echo -e { \"payments\": [{},{}]}"
  local key='.payments'
  count_key_in_command "$cmd" "$key"
}

countinvoices() {
  local cmd="/usr/bin/lightning-cli listinvoices"
  #local cmd="echo -e { \"invoices\": [{},{}]}"
  local key='.invoices'
  count_key_in_command "$cmd" "$key"
}

countchannels() {
  local cmd="/usr/bin/lightning-cli listchannels"
  #local cmd="echo -e { \"channels\": [{},{}]}"
  local key='.channels'
  count_key_in_command "$cmd" "$key"
}

countnodes() {
  local cmd="/usr/bin/lightning-cli listnodes"
  #local cmd="echo -e { \"nodes\": [{},{}]}"
  local key='.nodes'
  count_key_in_command "$cmd" "$key"
}

query_lightning_node() {
  local forward_count=0
  local peer_count=0
  local payment_count=0
  local invoice_count=0
  local channel_count=0
  local node_count=0

  local v

  v=$(countforwards)
  if [[ $v ]]; then
      forward_count=$v
  fi

  v=$(countpeers)
  if [[ $v ]]; then
      peer_count=$v
  fi

  v=$(countpayments)
  if [[ $v ]]; then
      payment_count=$v
  fi

  v=$(countinvoices)
  if [[ $v ]]; then
      invoice_count=$v
  fi

  v=$(countchannels)
  if [[ $v ]]; then
      channel_count=$v
  fi

  v=$(countnodes)
  if [[ $v ]]; then
      node_count=$v
  fi

  # write out influx line protocol
  # measurement,taglist(tag=value,tag=value) fieldlist(field=value,field=value) (timestamp[optional])
  echo -e ${MEASURMENT} forward_count=${forward_count}i,peer_count=${peer_count}i,payment_count=${payment_count}i,invoice_count=${invoice_count}i,channel_count=${channel_count}i,node_count=${node_count}i

}

query_lightning_node
