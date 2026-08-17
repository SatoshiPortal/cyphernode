#!/bin/sh

echo "Elements - Checking for new indexes in DB..."
count=$(sqlite3 $DB_FILE "select count(*) from sqlite_master where type='index' and name='idx_elements_watching_watching'")
if [ "${count}" -eq "0" ]; then
  # idx_elements_watching_watching not there, we have to migrate
  echo "Elements - Migrating database for new indexes..."
  echo "Elements - Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20210928_0.7.0-0.8.0_elements
  echo "Elements - Altering DB..."
  cat sqlmigrate20210928_0.7.0-0.8.0_elements.sql | sqlite3 $DB_FILE
else
  echo "Elements - New indexes migration already done, skipping!"
fi
