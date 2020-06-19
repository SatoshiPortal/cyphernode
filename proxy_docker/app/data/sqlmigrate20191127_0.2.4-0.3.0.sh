#!/bin/sh

echo "Checking for watching event support in DB..."
count=$(sqlite3 $DB_FILE "select count(*) from pragma_table_info('watching') where name='event_message'")
if [ "${count}" -eq "0" ]; then
	# event_message not there, we have to migrate
	echo "Migrating database for event triggered on watch notif..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20191127_0.2.4-0.3.0
  echo "Altering DB..."
	cat sqlmigrate20191127_0.2.4-0.3.0.sql | sqlite3 $DB_FILE
else
	echo "Database watching event support migration already done, skipping!"
fi
