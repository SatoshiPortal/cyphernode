#!/usr/bin/env sh
echo -n "$2" | dotnet WalletGenerator.dll generate --wallet:${1}