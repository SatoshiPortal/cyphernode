#!/bin/sh

walletnotify(){
  echo "[walletnotify-$$] Entering walletnotify"

  local txid="$@"
  echo "[walletnotify-$$] [txid=$txid]"
  local tx
  local error
  local topics="-t bitcoinnode/walletnotify"
  local watching_wallet

  for wallet in $(bitcoin-cli listwallets | tr -d ,\")
  do
    echo "[walletnotify-$$] tx=(bitcoin-cli -rpcwallet=$wallet gettransaction $txid true true)"
    tx=$(bitcoin-cli -rpcwallet="$wallet" gettransaction "$txid" true true 2>&1)
    error=$(echo ${tx} | grep 'error')
    
    if [ -z "${error}" ]; then
      tx=$(echo "$tx" | jq -Mc)
      echo "[walletnotify-$$] Found ["$txid"] in wallet ["$wallet"]"
      watching_wallet=$(echo $wallet | grep watching)

      if [ -n "${watching_wallet}" ]; then
        echo "[walletnotify-$$] It's a watching wallet ["$wallet"] - Adding topic cyphernode/bitcoin/walletnotify"
        topics="$topics -t cyphernode/bitcoin/walletnotify"
      fi
      break;
    else
      echo "[walletnotify-$$] Did not find ["$txid"] in wallet ["$wallet"] : ${error}"
    fi
  done

  echo "[walletnotify-$$] mosquitto_pub -h broker ${topics} -m \"$tx\" "
  mosquitto_pub -h broker ${topics} -m $(echo $tx | base64 -w 0)

  echo "[walletnotify-$$] Done"
}

walletnotify "$@"
