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

  if [ "${walletname}" = "watching01.dat" ] || [ "${walletname}" = "xpubwatching01.dat" ] || [ "${walletname}" = "spending01.dat" ]; then
    # Let's fetch transaction data in the spending wallet because there's too much missing information in the watching wallet for liquid transactions.
    # If we were watching an external address that is not in the spending wallet, too bad, it's not supported for now.
    echo "[walletnotify-$$] tx=(elements-cli -rpcwallet=spending01.dat gettransaction $txid true true)"
    tx=$(elements-cli -rpcwallet="spending01.dat" gettransaction "$txid" true true 2>&1)
    error=$(echo ${tx} | grep 'error')

    if [ -z "${error}" ]; then
      tx=$(echo "$tx" | jq -Mc)
      echo "[walletnotify-$$] Found ["$txid"] in wallet ["$walletname"]"
      watching_wallet=$(echo $walletname | grep watching)

      if [ -n "${watching_wallet}" ]; then
        echo "[walletnotify-$$] It's a watching wallet ["$walletname"] - Adding topic cyphernode/elements/walletnotify"
        echo "[walletnotify-$$] mosquitto_pub -h broker -t cyphernode/elements/walletnotify -m \"$tx\" "
        mosquitto_pub -h broker -t cyphernode/elements/walletnotify -m $(echo $tx | base64 -w 0)

        echo "[walletnotify-$$] mosquitto_pub -h broker -t elementsnode/walletnotify -m \"$tx\" "
        mosquitto_pub -h broker -t elementsnode/walletnotify -m $(echo $tx | base64 -w 0)
      fi
      break;
    else
      echo "[walletnotify-$$] Did not find ["$txid"] in wallet ["$walletname"] : ${error}"
    fi
  fi

  echo "[walletnotify-$$] Done"
}

walletnotify "$@"
