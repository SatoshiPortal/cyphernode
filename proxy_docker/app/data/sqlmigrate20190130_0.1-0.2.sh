#!/bin/sh

echo "Checking for watch by xpub support in DB..."
sqlite3 $DB_FILE ".tables" | grep "watching_by_pub32" > /dev/null
if [ "$?" -eq "1" ]; then
	# watching_by_pub32 not there, we have to migrate
	echo "Migrating database for watch by xpub support..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20190130_0.1-0.2
  echo "Altering DB..."
	cat sqlmigrate20190130_0.1-0.2.sql | sqlite3 $DB_FILE
else
	echo "Database watch by xpub support migration already done, skipping!"
fi
