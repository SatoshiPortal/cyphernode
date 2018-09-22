#!/bin/sh

. ./trace.sh

sql()
{
	trace "sqlite3 ${DB_FILE} '${1}'"
	sqlite3 -cmd ".timeout 20000" ${DB_FILE} "${1}"
	return $?
}

case "${0}" in *sql.sh) sql $@;; esac
