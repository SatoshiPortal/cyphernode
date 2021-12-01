#!/bin/sh

. ./trace.sh

trim() {
  echo -e "$1" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

createCurlConfig() {

  if [[ ''$1 == '' ]]; then
    trace "[startproxy] Missing file name: Check your *_BTC_NODE_RPC_CFG"
    return
  fi

  if [[ ''$2 == '' ]]; then
    trace "[startproxy] Missing content: Check your *_BTC_NODE_RPC_USER"
    return
  fi

  local user=$( trim $2 )
  echo "user=${user}" > ${1}

}

if [ -e ${DB_PATH}/.dbfailed ]; then
  touch /container_monitor/proxy_dbfailed
  trace "[startproxy] A previous database creation/migration failed.  Stopping."
  trace "[startproxy] A file called .dbfailed has been created.  Fix the migration errors, remove .dbfailed and retry."
  trace "[startproxy] Exiting."
  sleep 30
  exit 1
else
  rm -f /container_monitor/proxy_dbfailed
fi

trace "[startproxy] Waiting for PostgreSQL to be ready..."
while [ ! -f "/container_monitor/postgres_ready" ]; do echo "PostgreSQL not ready" ; sleep 10 ; done
trace "[startproxy] PostgreSQL ready!"

if [ ! -e ${DB_FILE} ]; then
  trace "[startproxy] DB not found, creating..."
  cat cyphernode.sql | sqlite3 $DB_FILE
  psql -h postgres -f cyphernode.postgresql -U cyphernode
  returncode=$?
  trace_rc ${returncode}
else
  trace "[startproxy] DB found, migrating..."
  for script in sqlmigrate*.sh; do
    sh $script
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -ne "0" ]; then
      break
    fi
  done
fi

if [ "${returncode}" -ne "0" ]; then
  touch ${DB_PATH}/.dbfailed
  touch /container_monitor/proxy_dbfailed
  trace "[startproxy] Database creation/migration failed.  Stopping."
  trace "[startproxy] A file called .dbfailed has been created in your proxy datapath.  Fix the migration errors, remove .dbfailed and retry."
  trace "[startproxy] Exiting."
  sleep 30
  exit ${returncode}
fi

rm -f /container_monitor/proxy_ready

chmod 0600 $DB_FILE

createCurlConfig ${WATCHER_BTC_NODE_RPC_CFG} ${WATCHER_BTC_NODE_RPC_USER}
createCurlConfig ${SPENDER_BTC_NODE_RPC_CFG} ${SPENDER_BTC_NODE_RPC_USER}

. ${DB_PATH}/config.sh
if [ "${FEATURE_LIGHTNING}" = "true" ]; then
  ./waitanyinvoice.sh &
fi

exec nc -vlkp${PROXY_LISTENING_PORT} -e ./requesthandler.sh
