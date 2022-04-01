#!/bin/sh

ELEMENTS_CLI='elements-cli'

<% if( net === 'regtest' ) { %>
ELEMENTS_CLI="$ELEMENTS_CLI -regtest"
<% } %>

while [ ! -f "/container_monitor/elements_ready" ]; do echo "CYPHERNODE: elementsd not ready" ; sleep 10 ; done

echo "CYPHERNODE: elementsd is ready"

# Check for the basic wallets.  If not present, create.
BASIC_WALLETS='"watching01.dat" "xpubwatching01.dat" "spending01.dat"'

CURRENT_WALLETS=`$ELEMENTS_CLI listwallets`

for wallet in $BASIC_WALLETS
do
    echo "CYPHERNODE: Checking wallet [$wallet]"
    echo "$CURRENT_WALLETS" | grep -F $wallet > /dev/null 2>&1

    if [ "$?" -ne "0" ]; then
       walletNameNoQuote=`echo $wallet | tr -d '"'`
       $ELEMENTS_CLI createwallet ${walletNameNoQuote} && echo "CYPHERNODE: new wallet created : [$walletNameNoQuote]"
    else
       echo "CYPHERNODE: Wallet [$wallet] found"
    fi
done