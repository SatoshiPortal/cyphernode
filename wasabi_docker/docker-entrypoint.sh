#!/usr/bin/env sh

termi() {
  echo "SIGTERM or SIGINT detected!"

  local dotnetpid=$(pidof dotnet)
  local torpid=$(pidof tor)
  echo "dotnetpid=${dotnetpid}"
  echo "torpid=${torpid}"

  kill -TERM ${dotnetpid} ${torpid}
  echo "Waiting for dotnet and tor to end..."

  while [ -e /proc/${dotnetpid} ] && [ -e /proc/${torpid} ]; do sleep 1; done
}

trap termi TERM INT

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
  (while [ "${walletloaded}" != "true" ]; do sleep 5 ; echo "CYPHERNODE: Trying to load Wasabi Wallet..." ; curl -s --config ${WASABI_RPC_CFG} -d '{"jsonrpc":"2.0","id":"0","method":"selectwallet", "params":["wasabi"]}' localhost:18099 > /dev/null ; [ "$?" = "0" ] && walletloaded=true ; done ; echo "CYPHERNODE: Wasabi Wallet loaded!") &

  /app/scripts/startWasabi.sh wasabi "" &
  wait $!

else
  echo "Wrong password"
fi
