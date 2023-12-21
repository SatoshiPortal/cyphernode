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
  printf "%s" "$1" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

# Need to wait for tor container so we don't try to connect to it (or bitcoin node etc) too early
while [ ! -f "/container_monitor/tor_ready" ]; do echo "tor not ready" ; sleep 5 ; done ; echo "tor ready!"

# Start the Tor service
service tor start

# Wait for Tor to be ready
while ! service tor status >/dev/null 2>&1; do
    echo "Waiting for Tor to start in container..."
    sleep 1
done

echo "Tor is running in container!"

cp /var/run/tor/control.authcookie ~/.walletwasabi/client/control_auth_cookie

while [ -z "${BITCOIN_IP}" ]; do echo "waiting for bitcoin ip" ; BITCOIN_IP=$(getent hosts bitcoin | awk '{ print $1 }') ; sleep 10 ; done
echo "bitcoin ip is ${BITCOIN_IP}"

network=$(cat /root/.walletwasabi/client/Config.json | jq -r '.Network')

cp /root/.walletwasabi/client/Config.json /root/.walletwasabi/client/Config-ori.json
# Wasabi needs an IP address for bitcoin p2p
if [ "$network" = "TestNet" ]; then
  jq --arg bitcoinip "${BITCOIN_IP}:18333" '.TestNetBitcoinP2pEndPoint = $bitcoinip' /root/.walletwasabi/client/Config-ori.json > /root/.walletwasabi/client/Config.json
elif [ "$network" = "RegTest" ]; then
  jq --arg bitcoinip "${BITCOIN_IP}:18444" '.RegTestBitcoinP2pEndPoint = $bitcoinip' /root/.walletwasabi/client/Config-ori.json > /root/.walletwasabi/client/Config.json
else
  jq --arg bitcoinip "${BITCOIN_IP}:8333" '.MainNetBitcoinP2pEndPoint = $bitcoinip' /root/.walletwasabi/client/Config-ori.json > /root/.walletwasabi/client/Config.json
fi

user=$( trim ${WASABI_RPC_USER} )
echo "user=${user}" > ${WASABI_RPC_CFG}

wallet_name=${WALLET_NAME:-wasabi}

# check if we have a wallet file
if [ "$network" = "TestNet" -o "$network" = "RegTest" ]; then
  if [ ! -d "/root/.walletwasabi/client/Wallets/$network" ]; then
    echo "Missing wallet directory. Creating it"
    mkdir -p "/root/.walletwasabi/client/Wallets/$network"
  fi
  if [ ! -f "/root/.walletwasabi/client/Wallets/$network/$wallet_name.json" ]; then
    echo "Missing wallet file. Generating wallet with name $wallet_name and saving the seed words"
    /app/scripts/generateWallet.sh $wallet_name > "/root/.walletwasabi/client/Wallets/$network/$wallet_name.seed"
  fi
else
  if [ ! -f "/root/.walletwasabi/client/Wallets/$wallet_name.json" ]; then
    echo "Missing wallet file. Generating wallet with name $wallet_name and saving the seed words"
    /app/scripts/generateWallet.sh $wallet_name > "/root/.walletwasabi/client/Wallets/$wallet_name.seed"
  fi
fi
  
dotnet WalletWasabi.Daemon.dll --wallet=$wallet_name &
wait $!
