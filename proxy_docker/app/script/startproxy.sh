#!/bin/sh

. ./trace.sh

trim() {
  echo "$1" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

createCurlConfig() {

  if [ ''$1 = '' ]; then
    trace "[startproxy] Missing file name: Check your *_BTC_NODE_RPC_CFG"
    return
  fi

  if [ ''$2 = '' ]; then
    trace "[startproxy] Missing content: Check your *_BTC_NODE_RPC_USER"
    return
  fi

  local user=$( trim $2 )
  echo "user=${user}" > ${1}

}

# If the file .dbfailed exists, it means we previously failed to process DB migrations.
# Sometimes, depending on timing, a migration fails but it doesn't mean it's corrupted.
# It may be a container that was not accessible for a short period of time, for example.
# So we'll try up to MAX_ATTEMPTS times before concluding in failure.

# For this to work, we'll put the number of attemps in the .dbfailed file.

MAX_ATTEMPTS=5

nb_attempts=1
if [ -e ${DB_PATH}/.dbfailed ]; then
  n=$(cat ${DB_PATH}/.dbfailed)
  nb_attempts=$((n+1))
fi

if [ "${nb_attempts}" -gt "${MAX_ATTEMPTS}" ]; then
  touch /container_monitor/proxy_dbfailed
  trace "[startproxy] Too many database creation/migration failed attempts.  Failed attempts = ${nb_attempts}."
  trace "[startproxy] A file called .dbfailed has been created in your proxy datapath.  Fix the migration errors, remove .dbfailed and retry."
  trace "[startproxy] Check your log files, especially postgres."
  trace "[startproxy] Exiting."
  sleep 30
  exit 1
else
  if [ "${nb_attempts}" -gt "1" ]; then
    trace "[startproxy] Current database creation/migration attempt = ${nb_attempts}.  Retrying..."
  fi
fi

trace "[startproxy] Waiting for PostgreSQL to be ready..."
while [ ! -f "/container_monitor/postgres_ready" ]; do trace "[startproxy] PostgreSQL not ready" ; sleep 10 ; done
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
  echo -n "${nb_attempts}" > ${DB_PATH}/.dbfailed
  trace "[startproxy] Database creation/migration failed.  We will retry ${MAX_ATTEMPTS} times."
  trace "[startproxy] A file called .dbfailed has been created in your proxy datapath.  Fix the migration errors, remove .dbfailed and retry."
  trace "[startproxy] Check your log files, especially postgres."
  trace "[startproxy] Exiting."
  sleep 30
  exit ${returncode}
fi

# /container_monitor/proxy_ready will be created by Docker's health check
rm -f /container_monitor/proxy_ready

rm -f /container_monitor/proxy_dbfailed
rm -f ${DB_PATH}/.dbfailed

chmod 0600 $DB_FILE

createCurlConfig ${WATCHER_BTC_NODE_RPC_CFG} ${WATCHER_BTC_NODE_RPC_USER}
createCurlConfig ${SPENDER_BTC_NODE_RPC_CFG} ${SPENDER_BTC_NODE_RPC_USER}

. ${DB_PATH}/config.sh
if [ "${FEATURE_LIGHTNING}" = "true" ]; then
  ./waitanyinvoice.sh &
fi

./bitcoin_node_walletnotify.sh &

#exec nc -vlkp${PROXY_LISTENING_PORT} -w 3m -e ./requesthandler.sh
exec nc -vlkp${PROXY_LISTENING_PORT} -w 3m -e ./aaaa.sh
