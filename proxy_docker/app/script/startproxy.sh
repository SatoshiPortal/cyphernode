#!/bin/sh

export PROXY_LISTENING_PORT
export WATCHER_NODE_RPC_URL=$WATCHER_BTC_NODE_RPC_URL
export SPENDER_NODE_RPC_URL=$SPENDER_BTC_NODE_RPC_URL
export WATCHER_NODE_RPC_CFG=$WATCHER_BTC_NODE_RPC_CFG
export SPENDER_NODE_RPC_CFG=$SPENDER_BTC_NODE_RPC_CFG
export TRACING
export DB_PATH
export DB_FILE

trim() {
	echo -e $1 | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

createCurlConfig() {

	if [[ ''$1 == '' ]]; then
		echo "Missing file name: Check you *_BTC_NODE_RPC_CFG"
		return
	fi

	if [[ ''$2 == '' ]]; then
		echo "Missing content: Check you *_BTC_NODE_RPC_USER"
		return
	fi

	local user=$( trim $2 )
	echo "user=${user}" > ${1}

}

if [ ! -e ${DB_FILE} ]; then
	echo "DB not found, creating..."
	cat cyphernode.sql | sqlite3 $DB_FILE
else
	echo "DB found, migrating..."
	for script in sqlmigrate*.sh; do
	  sh $script
	done
fi

chmod 0600 $DB_FILE

createCurlConfig ${WATCHER_BTC_NODE_RPC_CFG} ${WATCHER_BTC_NODE_RPC_USER}
createCurlConfig ${SPENDER_BTC_NODE_RPC_CFG} ${SPENDER_BTC_NODE_RPC_USER}

./waitanyinvoice.sh &

nc -vlkp${PROXY_LISTENING_PORT} -e ./requesthandler.sh
