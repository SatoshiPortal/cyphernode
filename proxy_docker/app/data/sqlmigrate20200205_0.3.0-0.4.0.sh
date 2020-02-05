#!/bin/sh

echo "Checking for elements support in DB..."
sqlite3 $DB_FILE ".tables" | grep "elements_tx" > /dev/null
if [ "$?" -eq "1" ]; then
	# elements_tx not there, we have to migrate
	echo "Migrating database for elements support..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20200205_0.3.0-0.4.0
  echo "Altering DB..."
	cat sqlmigrate20200205_0.3.0-0.4.0.sql | sqlite3 $DB_FILE
else
	echo "Database elements support migration already done, skipping!"
fi
