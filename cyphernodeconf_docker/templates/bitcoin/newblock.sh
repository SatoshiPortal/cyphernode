#!/bin/sh

blockhash="$@"
echo "[newblock] [$blockhash]"
mosquitto_pub -h broker -t bitcoin_node_newblock -m "$blockhash"
echo "[newblock] Done"