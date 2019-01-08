#!/bin/sh

exists=$(sqlite3 db/proxydb "SELECT value FROM cyphernode_props WHERE property='pay_index'")
if [ -z "${exists}" ]; then
	# pay_index not found, let's migrate
	echo "Migrating database from v0.1 to v0.2..."
	cat sqlmigrate20190104_0.1-0.2.sql | sqlite3 $DB_FILE
else
	echo "Database v0.1 to v0.2 migration already done, skipping!"
fi
