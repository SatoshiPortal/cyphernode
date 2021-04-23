#!/usr/bin/env sh

# Tor is not running as part of Cyphernode, try to kill it locally in here
termi_wtor() {
  echo "SIGTERM or SIGINT detected!"

  local dotnetpid=$(pidof dotnet)
  local torpid=$(pidof tor)
  echo "dotnetpid=${dotnetpid}"
  echo "torpid=${torpid}"

  kill -TERM ${dotnetpid} ${torpid}
  echo "Waiting for dotnet and tor to end..."

  while [ -e /proc/${dotnetpid} ] && [ -e /proc/${torpid} ]; do sleep 1; done
}

# Tor is running as part of Cyphernode, don't try to kill it locally in here
termi_wotor() {
  echo "SIGTERM or SIGINT detected!"

  local dotnetpid=$(pidof dotnet)

  echo "dotnetpid=${dotnetpid}"

  kill -TERM ${dotnetpid}
  echo "Waiting for dotnet to end..."

  while [ -e /proc/${dotnetpid} ]; do sleep 1; done
}

# If TOR_HOST is defined, it means Tor has been installed in Cyphernode setup, use it!
if [ -n "${TOR_HOST}" ]; then
  trap termi_wotor TERM INT
else
  trap termi_wtor TERM INT
fi

trim() {
	echo -e "$1" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

user=$( trim ${WASABI_RPC_USER} )
echo "user=${user}" > ${WASABI_RPC_CFG}

wallet_name=${WALLET_NAME:-wasabi}

# check if we have a wallet file
if [ ! -f "/root/.walletwasabi/client/Wallets/$wallet_name.json" ]; then
  echo "Missing wallet file. Generating wallet with name $wallet_name and saving the seed words"
  echo "" | /app/scripts/generateWallet.sh $wallet_name > "/root/.walletwasabi/client/Wallets/$wallet_name.seed"
fi

# From here on the wallet file exists, start mixer
/app/scripts/checkWalletPassword.sh $wallet_name ""

if [ $? = 0 ]; then
  # If TOR_HOST is defined, it means Tor has been installed in Cyphernode setup, use it!
  if [ -n "${TOR_HOST}" ]; then
    while [ -z "${TORIP}" ]; do echo "tor not ready" ; TORIP=$(getent hosts tor | awk '{ print $1 }') ; sleep 10 ; done
    echo "tor ready at IP ${TORIP}"
    cp /root/.walletwasabi/client/Config.json /root/.walletwasabi/client/Config-ori.json
    # Wasabi needs an IP address as the Tor socks5 endpoint, unfortunately
    jq --arg torip "${TORIP}:${TOR_PORT}" '.TorSocks5EndPoint = $torip' /root/.walletwasabi/client/Config-ori.json > /root/.walletwasabi/client/Config.json
  else
    echo "Tor will be launched locally with Wasabi"
    cp /root/.walletwasabi/client/Config.json /root/.walletwasabi/client/Config-ori.json
    jq --arg torip "127.0.0.1:9050" '.TorSocks5EndPoint = $torip' /root/.walletwasabi/client/Config-ori.json > /root/.walletwasabi/client/Config.json
  fi

  (while [ "${walletloaded}" != "true" ]; do sleep 5 ; echo "CYPHERNODE: Trying to load Wasabi Wallet..." ; curl -s --config ${WASABI_RPC_CFG} -d '{"jsonrpc":"2.0","id":"0","method":"selectwallet", "params":["wasabi"]}' localhost:18099 > /dev/null ; [ "$?" = "0" ] && walletloaded=true ; done ; echo "CYPHERNODE: Wasabi Wallet loaded!") &

  /app/scripts/startWasabi.sh wasabi "" &
  wait $!

else
  echo "Wrong password"
fi
