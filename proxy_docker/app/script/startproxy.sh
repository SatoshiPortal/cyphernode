#!/bin/sh

. ${DB_PATH}/config.sh
. ./walletutils.sh

export PROXY_LISTENING_PORT
export WATCHER_NODE_RPC_URL=$WATCHER_BTC_NODE_RPC_URL
export SPENDER_NODE_RPC_URL=$SPENDER_BTC_NODE_RPC_URL
export WATCHER_NODE_RPC_CFG=$WATCHER_BTC_NODE_RPC_CFG
export SPENDER_NODE_RPC_CFG=$SPENDER_BTC_NODE_RPC_CFG
export TRACING
export DB_PATH
export DB_FILE

_trim() {
	echo -e "$1" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

_createCurlConfig() {

	if [[ ''$1 == '' ]]; then
		echo "Missing file name: Check you *_BTC_NODE_RPC_CFG"
		return
	fi

	if [[ ''$2 == '' ]]; then
		echo "Missing content: Check you *_BTC_NODE_RPC_USER"
		return
	fi

	local user=$( _trim $2 )
	echo "user=${user}" > ${1}

}

init_dbfile() {
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
}

init_curlconfig() {
  _createCurlConfig ${WATCHER_BTC_NODE_RPC_CFG} ${WATCHER_BTC_NODE_RPC_USER}
  _createCurlConfig ${SPENDER_BTC_NODE_RPC_CFG} ${SPENDER_BTC_NODE_RPC_USER}
}

init_psbt() {
  # if we have psbt enabled and there is no psbt01 wallet existing
  # we will need to call create_wallet to tell bitcoin core that we
  # need a wallet without private keys to which we will import
  # a watch only xpub using importmulti

  # Try to create the psbt wallet when psbt is enabled

  # will create a blank wallet with private keys disabled
  if [ "$PSBT_WALLET_ACTIVE" == "true" ]; then
    echo "checking psbt wallet"
    local result=$(create_wallet "psbt01")
    if [ "$?" -eq 0 ]; then
      local error=$(echo $result | jq '.error')
      if [ "$error" == "null" ]; then
        echo -n 'INFO: '
        echo $error | jq '.message'
      fi
    fi
  else
    echo "psbt feature is disabled"
  fi


}

init() {
  init_dbfile
  init_curlconfig
  init_psbt
}

run() {
  if [ "${FEATURE_LIGHTNING}" = "true" ]; then
    ./waitanyinvoice.sh &
  fi
  nc -vlkp${PROXY_LISTENING_PORT} -e ./requesthandler.sh
}

# startup
init
run
