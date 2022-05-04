#!/bin/sh

. ./trace.sh

sql() {
  trace "Entering sql()..."

  local select_id=${2}
  local response
  local inserted_id

  trace "[sql] psql -qAtX -h postgres -U cyphernode -c \"${1}\""
  response=$(psql -qAtX -h postgres -U cyphernode -c "${1}")
  returncode=$?
  trace_rc ${returncode}

  if [ -n "${select_id}" ]; then
    if [ "${returncode}" -eq "0" ]; then
      inserted_id=$(echo "${response}" | cut -d ' ' -f1)
    else
      trace "[sql] psql -qAtX -h postgres -U cyphernode -c \"${select_id}\""
      inserted_id=$(psql -qAtX -h postgres -U cyphernode -c "${select_id}")
      returncode=$?
      trace_rc ${returncode}
    fi
    echo -n "${inserted_id}"
  else
    echo -n "${response}"
  fi

  return ${returncode}
}

waitfortable(){
  TABLE_NAME=$1

  trace "Entering waitfortable [$TABLE_NAME]"

  while true; do

    exists=$(psql -qAtX -h postgres -U cyphernode -c "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname='public' and tablename='$TABLE_NAME')")

    if [ "${exists}" = "t" ]; then
      trace "Table found [$TABLE_NAME] -  Exiting"
      break
    fi

    trace "wainting for table [$TABLE_NAME] to exist"
    sleep 5
  done
}
