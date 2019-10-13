#!/usr/bin/env sh

wallet_name=${WALLET_NAME:-wasabi}

# check if we have a wallet file
if [ ! -f "/root/.walletwasabi/client/Wallets/$wallet_name.json" ]; then
  echo "Missing wallet file. Generating wallet with name $wallet_name and saving the seed words"
  echo "" | /app/scripts/generateWallet.sh $wallet_name > "/root/.walletwasabi/client/Wallets/$wallet_name.seed"
fi

# From here on the wallet file exists, start mixer
/app/scripts/checkWalletPassword.sh $wallet_name ""

if [ $? = 0 ]; then
  exec /app/scripts/startWasabi.sh $wallet_name ""
else
  echo "Wrong password"
fi

