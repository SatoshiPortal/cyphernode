#!/bin/sh

conf(){
  local pid=$(cut -d' ' -f4 < /proc/self/stat)
  echo "[conf-$pid] Entering conf"

  local txid="$@"
  echo "[conf-$pid] [txid=$txid]"
  local tx

  for wallet in $(bitcoin-cli listwallets | grep watching | tr -d ,\")
  do
    echo "[conf-$pid] tx=(bitcoin-cli -rpcwallet=$wallet gettransaction $txid true)"
    tx=$(bitcoin-cli -rpcwallet=$wallet gettransaction $txid true)

    if [ -n "$tx" ]; then
      echo "[conf-$pid] Found [$txid] in wallet [$wallet]"
      echo "[conf-$pid] mosquitto_pub -h broker -t confirmation -m \"$tx\" "
      mosquitto_pub -h broker -t confirmation -m $(echo $tx | base64 -w 0)
      break;
    fi
  done

  echo "[conf-$pid] Done"
}

conf $@