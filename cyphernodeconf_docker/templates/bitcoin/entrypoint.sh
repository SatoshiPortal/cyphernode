#!/bin/sh

rm -f /container_monitor/bitcoin_ready

<% if ( features.indexOf('tor') !== -1 && torifyables && torifyables.indexOf('tor_bitcoin') !== -1 ) { %>
while [  ! -f "/container_monitor/tor_ready" ];
do
    echo "CYPHERNODE[entrypoint]: Waiting for Tor to be ready before starting bitcoind"
    sleep 10
done
echo "CYPHERNODE[entrypoint]: Tor is ready - Starting bitcoind"
<% } %>

# Create default wallets if they are not loaded
/.bitcoin/createWallets.sh &

<% if( net === 'regtest' ) { %>
/.bitcoin/mine.sh &
<% } %>

exec bitcoind
