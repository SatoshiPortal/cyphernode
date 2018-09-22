#!/bin/sh

export PROXY_LISTENING_PORT
export WATCHER_NODE_RPC_URL=$WATCHER_BTC_NODE_RPC_URL
export SPENDER_NODE_RPC_URL=$SPENDER_BTC_NODE_RPC_URL
export TRACING
export DB_PATH
export DB_FILE

if [ ! -e ${DB_FILE} ]; then
	echo "DB not found, creating..." > /dev/stderr
	cat watching.sql | sqlite3 $DB_FILE
fi

nc -vlkp${PROXY_LISTENING_PORT} -e ./requesthandler.sh
