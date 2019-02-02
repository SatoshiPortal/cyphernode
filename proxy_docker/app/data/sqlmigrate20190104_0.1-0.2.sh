#!/bin/sh

echo "Checking for full LN support in DB..."
exists=$(sqlite3 db/proxydb "SELECT value FROM cyphernode_props WHERE property='pay_index'")
if [ -z "${exists}" ]; then
	# pay_index not found, let's migrate
	echo "Migrating database for full LN support..."
	cat sqlmigrate20190104_0.1-0.2.sql | sqlite3 $DB_FILE
else
	echo "Database full LN support migration already done, skipping!"
fi
