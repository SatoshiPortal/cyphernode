#!/bin/sh

walletnotify(){
  echo "[walletnotify-$$] Entering walletnotify"

  local txid="$1"
  echo "[walletnotify-$$] [txid=$txid]"
  local walletname="$2"
  echo "[walletnotify-$$] [walletname=$walletname]"
  local tx
  local error
  local watching_wallet

  # The Bitcoin node may have several other wallets used for other purposes than the ones by Cyphernode, so
  # we need to filter out the transactions from those other wallets before publishing them to the Cyphernode MQTT topics.

  # We are using the cyphernode/bitcoin/walletnotify topic for Cyphernode purposes (watcher, confirmation management, etc.) and
  # using the bitcoinnode/walletnotify topic for other purposes, like the cypherapps that are subscribed to it on the broker.
  # We are only publishing transactions useful for Cyphernode on the Cyphernode's topic and all the others to the Cypherapps one.

  if [ "${walletname}" = "watching01.dat" ] || [ "${walletname}" = "xpubwatching01.dat" ] || [ "${walletname}" = "spending01.dat" ]; then
    echo "[walletnotify-$$] tx=(bitcoin-cli -rpcwallet=$walletname gettransaction $txid true true)"
    tx=$(bitcoin-cli -rpcwallet="$walletname" gettransaction "$txid" true true 2>&1)
    error=$(echo ${tx} | grep 'error')

    if [ -z "${error}" ]; then
      tx=$(echo "$tx" | jq -Mc)
      echo "[walletnotify-$$] Found ["$txid"] in wallet ["$walletname"]"
      watching_wallet=$(echo $walletname | grep watching)

      if [ -n "${watching_wallet}" ]; then
        echo "[walletnotify-$$] It's a watching wallet ["$walletname"] - Adding topic cyphernode/bitcoin/walletnotify"
        echo "[walletnotify-$$] mosquitto_pub -h broker -t cyphernode/bitcoin/walletnotify -m \"$tx\" "
        mosquitto_pub -h broker -t cyphernode/bitcoin/walletnotify -m $(echo $tx | base64 -w 0)
      fi

      echo "[walletnotify-$$] mosquitto_pub -h broker -t bitcoinnode/walletnotify -m \"$tx\" "
      mosquitto_pub -h broker -t bitcoinnode/walletnotify -m $(echo $tx | base64 -w 0)
    else
      echo "[walletnotify-$$] Did not find ["$txid"] in wallet ["$walletname"] : ${error}"
    fi
  fi

  echo "[walletnotify-$$] Done"
}

walletnotify "$@"
