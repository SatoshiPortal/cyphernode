#!/bin/sh

BITCOIN_CLI='bitcoin-cli'

while [ -z "`bitcoin-cli echo`"  ]; do echo "CYPHERNODE[createWallet]: bitcoind not ready" ; sleep 10 ; done
echo "CYPHERNODE[createWallet]: bitcoind is ready"

walletNameNoQuote="watching01.dat"
$BITCOIN_CLI -named createwallet wallet_name=${walletNameNoQuote} descriptors=false disable_private_keys=true \
&& echo "CYPHERNODE[createWallet]: new wallet created : [$walletNameNoQuote]" \
|| echo "CYPHERNODE[createWallet]: Wallet [$walletNameNoQuote] found"

walletNameNoQuote="xpubwatching01.dat"
$BITCOIN_CLI -named createwallet wallet_name=${walletNameNoQuote} descriptors=false disable_private_keys=true \
&& echo "CYPHERNODE[createWallet]: new wallet created : [$walletNameNoQuote]" \
|| echo "CYPHERNODE[createWallet]: Wallet [$walletNameNoQuote] found"

walletNameNoQuote="spending01.dat"
$BITCOIN_CLI -named createwallet wallet_name=${walletNameNoQuote} descriptors=true disable_private_keys=false \
&& echo "CYPHERNODE[createWallet]: new wallet created : [$walletNameNoQuote]" \
|| echo "CYPHERNODE[createWallet]: Wallet [$walletNameNoQuote] found"

<% if( net === 'regtest' ) { %>
BLOCKS_TO_MINE=101

MIN_BALANCE=1.00000000
balance=`bitcoin-cli -rpcwallet=spending01.dat getbalance`
echo "CYPHERNODE[createWallet]: Current balance [$balance] - Min balance is [$MIN_BALANCE]"

[ `expr $balance \>= $MIN_BALANCE` -eq 0 ] && \
  echo "CYPHERNODE[createWallet]: Balance is less than $MIN_BALANCE - mining $BLOCKS_TO_MINE blocks" && \
  bitcoin-cli -rpcwallet=spending01.dat -generate $BLOCKS_TO_MINE && \
  echo "CYPHERNODE[createWallet]: Done mining $BLOCKS_TO_MINE blocks"
<% } %>
