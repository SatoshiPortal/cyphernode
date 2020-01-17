#!/bin/sh

echo "Checking for OTS support in DB..."
sqlite3 $DB_FILE ".tables" | grep "stamp" > /dev/null
if [ "$?" -eq "1" ]; then
	# stamp not there, we have to migrate
	echo "Migrating database for OTS support..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20181213_0-0.1
  echo "Altering DB..."
	cat sqlmigrate20181213_0-0.1.sql | sqlite3 $DB_FILE
else
	echo "Database OTS support migration already done, skipping!"
fi
