#!/bin/sh

trim() {
  echo -e "$1" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

createCurlConfig() {

  if [[ ''$1 == '' ]]; then
    echo "Missing file name: Check your *_BTC_NODE_RPC_CFG"
    return
  fi

  if [[ ''$2 == '' ]]; then
    echo "Missing content: Check your *_BTC_NODE_RPC_USER"
    return
  fi

  local user=$( trim $2 )
  echo "user=${user}" > ${1}

}

if [ ! -e ${DB_FILE} ]; then
  echo "DB not found, creating..."
  cat cyphernode.sql | sqlite3 $DB_FILE
  psql -h postgres -f cyphernode.postgresql -U cyphernode
else
  echo "DB found, migrating..."
  for script in sqlmigrate*.sh; do
    sh $script
  done
fi

chmod 0600 $DB_FILE

createCurlConfig ${WATCHER_BTC_NODE_RPC_CFG} ${WATCHER_BTC_NODE_RPC_USER}
createCurlConfig ${SPENDER_BTC_NODE_RPC_CFG} ${SPENDER_BTC_NODE_RPC_USER}

. ${DB_PATH}/config.sh
if [ "${FEATURE_LIGHTNING}" = "true" ]; then
  ./waitanyinvoice.sh &
fi

exec nc -vlkp${PROXY_LISTENING_PORT} -e ./requesthandler.sh
