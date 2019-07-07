#!/usr/bin/env sh
tor &
dotnet WalletWasabi.Gui.dll mix --wallet:$1 --mixall --keepalive