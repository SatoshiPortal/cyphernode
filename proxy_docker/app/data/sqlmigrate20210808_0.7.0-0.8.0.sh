#!/bin/sh

echo "Checking for labels for watched addresses support in DB..."
count=$(sqlite3 $DB_FILE "select count(*) from pragma_table_info('watching') where name='label'")
if [ "${count}" -eq "0" ]; then
	# label not there, we have to migrate
	echo "Migrating database for labels for watched addresses support..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20210808_0.7.0-0.8.0
  echo "Altering DB..."
	cat sqlmigrate20210808_0.7.0-0.8.0.sql | sqlite3 $DB_FILE
else
	echo "Database labels for watched addresses support migration already done, skipping!"
fi
