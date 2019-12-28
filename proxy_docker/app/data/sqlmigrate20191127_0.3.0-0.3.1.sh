#!/bin/sh

echo "Checking for recipient wallet name support in DB..."
count=$(sqlite3 $DB_FILE "select count(*) from pragma_table_info('recipient') where name='wallet_name'")
if [ "${count}" -eq "0" ]; then
	# event_message not there, we have to migrate
	echo "Migrating database for wallet name in recipient..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20191127_0.3.0-0.3.1
  echo "Altering DB..."
	cat sqlmigrate20191127_0.3.0-0.3.1.sql | sqlite3 $DB_FILE
else
	echo "Database wallet name in recipient migration already done, skipping!"
fi
