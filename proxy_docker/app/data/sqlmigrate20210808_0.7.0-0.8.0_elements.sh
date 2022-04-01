#!/bin/sh

echo "Elements - Checking for labels for watched addresses support in DB..."
count=$(sqlite3 $DB_FILE "select count(*) from pragma_table_info('elements_watching') where name='label'")
if [ "${count}" -eq "0" ]; then
  # label not there, we have to migrate
  echo "Elements - Migrating database for labels for watched addresses support..."
  echo "Elements - Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20210808_0.7.0-0.8.0_elements
  echo "Elements - Altering DB..."
  cat sqlmigrate20210808_0.7.0-0.8.0_elements.sql | sqlite3 $DB_FILE
else
  echo "Elements - Database labels for watched addresses support migration already done, skipping!"
fi
