#!/bin/sh

BITCOIN_CLI='bitcoin-cli'

<% if( net === 'regtest' ) { %>
BITCOIN_CLI="$BITCOIN_CLI -regtest"
<% } %>

USER="`id -u -n`:`id -g -n`"

while [ true ];
do
    sleep 10;
    echo "CYPHERNODE: bitcoind is starting"
    chown $USER /container_monitor && ${BITCOIN_CLI} echo && touch /container_monitor/bitcoin_ready && chown $USER /container_monitor/bitcoin_ready && break || rm -f /container_monitor/bitcoin_ready
done

echo "CYPHERNODE: bitcoind is ready"

# Check for the basic wallets.  If not present, create.
BASIC_WALLETS='"watching01.dat" "xpubwatching01.dat" "spending01.dat"'

CURRENT_WALLETS=`$BITCOIN_CLI listwallets`

for wallet in $BASIC_WALLETS
do
    echo "CYPHERNODE: Checking wallet [$wallet]"
    echo "$CURRENT_WALLETS" | grep -F $wallet > /dev/null 2>&1

    if [ "$?" -ne "0" ]; then
       walletNameNoQuote=`echo $wallet | tr -d '"'`
       $BITCOIN_CLI createwallet ${walletNameNoQuote} && echo "CYPHERNODE: new wallet created : [$walletNameNoQuote]"
    else
       echo "CYPHERNODE: Wallet [$wallet] found"
    fi
done