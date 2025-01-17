#!/bin/sh

rm -f /container_monitor/elements_ready

<% if ( features.indexOf('tor') !== -1 && torifyables && torifyables.indexOf('tor_elements') !== -1 ) { %>
while [  ! -f "/container_monitor/tor_ready" ];
do
    echo "CYPHERNODE[entrypoint]: Waiting for Tor to be ready before starting elementsd"
    sleep 10
done
echo "CYPHERNODE[entrypoint]: Tor is ready - Starting elementsd"
<% } %>

# Create default wallets if they are not loaded
/.elements/createWallets.sh &

exec elementsd
