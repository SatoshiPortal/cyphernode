#!/bin/sh

rm -f /container_monitor/bitcoin_ready

/.bitcoin/createWallets.sh &

exec bitcoind
