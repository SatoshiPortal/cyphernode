#!/bin/sh

walletnotify(){
  local pid=$(cut -d' ' -f4 < /proc/self/stat)
  echo "[walletnotify-$pid] Entering walletnotify"

  local txid="$@"
  echo "[walletnotify-$pid] [txid=$txid]"
  local tx

  for wallet in $(bitcoin-cli listwallets | grep watching | tr -d ,\")
  do
    echo "[walletnotify-$pid] tx=(bitcoin-cli -rpcwallet=$wallet gettransaction $txid true)"
    tx=$(bitcoin-cli -rpcwallet=$wallet gettransaction $txid true)

    if [ -n "$tx" ]; then
      echo "[walletnotify-$pid] Found [$txid] in wallet [$wallet]"
      echo "[walletnotify-$pid] mosquitto_pub -h broker -t confirmation -m \"$tx\" "
      mosquitto_pub -h broker -t confirmation -m $(echo $tx | base64 -w 0)
      break;
    fi
  done

  echo "[walletnotify-$pid] Done"
}

walletnotify $@