#!/bin/sh

walletnotify(){
  echo "[walletnotify-$$] Entering walletnotify"

  local txid="${1}"
  echo "[walletnotify-$$] [txid=${txid}]"
  local walletname="${2}"
  echo "[walletnotify-$$] [walletname=${walletname}]"
  local tx
  local returncode
  local rpc_wallet
  local publish_core=false

  # The Elements node may have several other wallets used for other purposes than the ones by Cyphernode, so
  # we need to filter out the transactions from those other wallets before publishing them to the Cyphernode MQTT topics.

  # We are using the cyphernode/elements/walletnotify topic for Cyphernode purposes (watcher, confirmation management, etc.) and
  # using the elementsnode/walletnotify topic for other purposes, like the cypherapps that are subscribed to it on the broker.
  # We are only publishing transactions useful for Cyphernode on the Cyphernode's topic and all of them to the Cypherapps one.

  # Spending wallets have complete transaction details in their own view. The
  # watch-only wallets do not have the blinding data needed by Cyphernode, so
  # preserve the established default-spender lookup for those notifications.
  rpc_wallet=${walletname}
  case "${walletname}" in
    spending0[1-4].dat)
      publish_core=true
      ;;
    watching01.dat|xpubwatching01.dat)
      rpc_wallet=spending01.dat
      publish_core=true
      ;;
  esac

  echo "[walletnotify-$$] tx=(elements-cli -rpcwallet=${rpc_wallet} gettransaction ${txid} true true)"
  tx=$(elements-cli -rpcwallet="${rpc_wallet}" gettransaction "${txid}" true true 2>&1)
  returncode=$?

  if [ "${returncode}" -eq 0 ]; then
    echo "[walletnotify-$$] Found [${txid}] in wallet [${walletname}]"
    tx=$(echo "${tx}" | jq -Mc)
    txb64=$(echo "${tx}" | base64 -w 0)
    tmpfile=$(mktemp)
    echo -n "${txb64}" > "${tmpfile}"

    if ${publish_core}; then
      echo "[walletnotify-$$] It's a supported Cyphernode wallet [${walletname}] - Adding topic cyphernode/elements/walletnotify"
      echo "[walletnotify-$$] mosquitto_pub -h broker -t cyphernode/elements/walletnotify -f \"${tmpfile}\""
      mosquitto_pub -h broker -t cyphernode/elements/walletnotify -f "${tmpfile}"
    fi

    echo "[walletnotify-$$] mosquitto_pub -h broker -t elementsnode/walletnotify -f \"${tmpfile}\""
    mosquitto_pub -h broker -t elementsnode/walletnotify -f "${tmpfile}"

    rm "${tmpfile}"
  else
    echo "[walletnotify-$$] Did not find [${txid}] in wallet [${walletname}] : ${tx}"
  fi

  echo "[walletnotify-$$] Done"
}

walletnotify "$@"
