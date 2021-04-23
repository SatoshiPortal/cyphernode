#!/usr/bin/env sh

# If TOR_HOST is not defined, it means Tor has not been installed in Cyphernode setup,
# let's launch a local instance!
if [ -z "${TOR_HOST}" ]; then
  tor &
fi

#dotnet WalletWasabi.Gui.dll mix --wallet:$1 --mixall --keepalive
dotnet WalletWasabi.Gui.dll mix --wallet:$1 --keepalive
