#!/bin/sh

echo "Checking for watch by descriptor support in DB..."
sqlite3 $DB_FILE ".tables" | grep "watching_by_descriptor" > /dev/null
if [ "$?" -eq "1" ]; then
	# watching_by_pub32 not there, we have to migrate
	echo "Migrating database for watch by descriptor support..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20200124_0.3.0-0.3.1
  echo "Altering DB..."
	cat sqlmigrate20200124_0.3.0-0.3.1.sql | sqlite3 $DB_FILE
else
	echo "Database watch by descriptor support migration already done, skipping!"
fi
