#!/bin/sh

blockhash="$@"
echo "[pubNewBlock] [$blockhash]"
mosquitto_pub -h broker -t bitcoin_node_newblock -m "$blockhash"
echo "[pubNewBlock] Done"