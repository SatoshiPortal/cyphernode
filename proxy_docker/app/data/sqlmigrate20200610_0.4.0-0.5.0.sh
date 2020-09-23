#!/bin/sh

echo "Checking for extended batching support in DB..."
count=$(sqlite3 $DB_FILE "select count(*) from pragma_table_info('recipient') where name='batcher_id'")
if [ "${count}" -eq "0" ]; then
	# batcher_id not there, we have to migrate
	echo "Migrating database for extended batching support..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20200610_0.4.0-0.5.0
  echo "Altering DB..."
	cat sqlmigrate20200610_0.4.0-0.5.0.sql | sqlite3 $DB_FILE
else
	echo "Database extended batching support migration already done, skipping!"
fi
