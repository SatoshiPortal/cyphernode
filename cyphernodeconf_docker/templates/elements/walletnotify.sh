#!/bin/sh

walletnotify(){
  echo "[walletnotify-$$] Entering walletnotify"

  local txid="${1}"
  echo "[walletnotify-$$] [txid=${txid}]"
  local walletname="${2}"
  echo "[walletnotify-$$] [walletname=${walletname}]"
  local tx
  local error
  local watching_wallet

  # The Elements node may have several other wallets used for other purposes than the ones by Cyphernode, so
  # we need to filter out the transactions from those other wallets before publishing them to the Cyphernode MQTT topics.

  # We are using the cyphernode/elements/walletnotify topic for Cyphernode purposes (watcher, confirmation management, etc.) and
  # using the elementsnode/walletnotify topic for other purposes, like the cypherapps that are subscribed to it on the broker.
  # We are only publishing transactions useful for Cyphernode on the Cyphernode's topic and all of them to the Cypherapps one.

  # Let's fetch transaction data in the spending wallet because there's too much missing information in the watching wallet for liquid transactions.
  # If we were watching an external address that is not in the spending wallet, it's too bad, it's not supported for now.
  echo "[walletnotify-$$] tx=(elements-cli -rpcwallet=spending01.dat gettransaction ${txid} true true)"
  tx=$(elements-cli -rpcwallet="spending01.dat" gettransaction "${txid}" true true 2>&1)
  error=$(echo ${tx} | grep 'error')

  if [ -z "${error}" ]; then
    echo "[walletnotify-$$] Found ["$txid"] in wallet ["$walletname"]"
    tx=$(echo "${tx}" | jq -Mc)
    txb64=$(echo ${tx} | base64 -w 0)

    if [ "${walletname}" = "watching01.dat" ] || [ "${walletname}" = "xpubwatching01.dat" ]; then
      echo "[walletnotify-$$] It's a watching wallet ["${walletname}"] - Adding topic cyphernode/elements/walletnotify"
      echo "[walletnotify-$$] mosquitto_pub -h broker -t cyphernode/elements/walletnotify -m \"${tx}\" "
      mosquitto_pub -h broker -t cyphernode/elements/walletnotify -m "${txb64}"
    fi

    echo "[walletnotify-$$] mosquitto_pub -h broker -t elementsnode/walletnotify -m \"${tx}\" "
    mosquitto_pub -h broker -t elementsnode/walletnotify -m "${txb64}"
  else
    echo "[walletnotify-$$] Did not find ["$txid"] in wallet ["${walletname}"] : ${error}"
  fi

  echo "[walletnotify-$$] Done"
}

walletnotify "$@"
