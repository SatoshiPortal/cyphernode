#!/bin/sh

sqlite3 db/proxydb ".tables" | grep "stamp" > /dev/null
if [ "$?" -eq "1" ]; then
	# stamp not there, we have to migrate
	echo "Migrating database from v0 to v0.1..."
	cat sqlmigrate20181213_0-0.1.sql | sqlite3 $DB_FILE
else
	echo "Database v0 to v0.1 migration already done, skipping!"
fi
