#!/bin/sh

. ./trace.sh

sql() {
  trace "sqlite3 -cmd \".timeout 40000\" ${DB_FILE} \"${1}\""
  sqlite3 -cmd ".timeout 40000" ${DB_FILE} "${1}"

  if [ "$?" -ne 0 ]; then
    # SQL didn't work, let's retry to be sure...
    trace "SQL didn't work, let's retry..."
    sqlite3 -cmd ".timeout 40000" ${DB_FILE} "${1}"
  fi

  return $?
}

sql_rawtx() {
  trace "sqlite3 -cmd \".timeout 40000\" ${DB_FILE}_rawtx \"${1}\""
  sqlite3 -cmd ".timeout 40000" ${DB_FILE}_rawtx "${1}"

  if [ "$?" -ne 0 ]; then
    # SQL didn't work, let's retry to be sure...
    trace "SQL didn't work, let's retry..."
    sqlite3 -cmd ".timeout 40000" ${DB_FILE}_rawtx "${1}"
  fi

  return $?
}
