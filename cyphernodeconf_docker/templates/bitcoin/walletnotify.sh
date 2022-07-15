#!/bin/sh

walletnotify(){
  echo "[walletnotify-$$] Entering walletnotify"

  local txid="$@"
  echo "[walletnotify-$$] [txid=$txid]"
  local tx

  for wallet in $(bitcoin-cli listwallets | grep watching | tr -d ,\")
  do
    echo "[walletnotify-$$] tx=(bitcoin-cli -rpcwallet=$wallet gettransaction $txid true true)"
    tx=$(bitcoin-cli -rpcwallet=$wallet gettransaction $txid true true)
    tx=$(echo $tx | jq -Mc)

    if [ -n "$tx" ]; then
      echo "[walletnotify-$$] Found [$txid] in wallet [$wallet]"
      echo "[walletnotify-$$] mosquitto_pub -h broker -t bitcoin_watching_walletnotify -m \"$tx\" "
      mosquitto_pub -h broker -t bitcoin_watching_walletnotify -m $(echo $tx | base64 -w 0)
      break;
    fi
  done

  echo "[walletnotify-$$] Done"
}

walletnotify "$@"
