#!/bin/sh

. ./trace.sh

sql() {
	trace "sqlite3 -cmd \".timeout 25000\" ${DB_FILE} \"${1}\""
  sqlite3 -cmd ".timeout 25000" ${DB_FILE} "${1}"
#  sqlite3 ${DB_FILE} "PRAGMA busy_timeout=20000; ${1}"

	return $?
}

sql_rawtx() {
	trace "sqlite3 -cmd \".timeout 25000\" ${DB_FILE}_rawtx \"${1}\""
  sqlite3 -cmd ".timeout 25000" ${DB_FILE}_rawtx "${1}"
#  sqlite3 ${DB_FILE} "PRAGMA busy_timeout=20000; ${1}"

	return $?
}
