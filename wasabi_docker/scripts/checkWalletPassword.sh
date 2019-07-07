#!/usr/bin/env sh
echo -n "$2" | dotnet WalletGenerator.dll check --wallet:${1}
