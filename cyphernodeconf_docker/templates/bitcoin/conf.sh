#!/bin/sh

conf(){
  echo "[conf] Entering conf"

  local txid="$@"
  echo "[conf] [txid=$txid]"
  local tx

  for wallet in $(bitcoin-cli listwallets | grep ing | tr -d ,\")
  do
    echo "trx=(bitcoin-cli -rpcwallet=$wallet gettransaction  $txid)"
    tx=$(bitcoin-cli -rpcwallet=$wallet gettransaction $txid)
    echo "trx gettransaction [$trx]"

    if [ -n "$tx" ]; then
      break;
    fi
  done
 
  echo "[conf] mosquitto_pub -h broker -t confirmation -m \"$tx\" "
  mosquitto_pub -h broker -t confirmation -m $(echo $tx | base64 -w 0)
}


conf $@