#!/bin/sh

echo "Checking for new indexes in DB..."
sqlite3 $DB_FILE ".indexes" | grep "idx_watching_watching" > /dev/null
if [ "$?" -eq "1" ]; then
  # idx_watching_watching index not found
  echo "Migrating database with new indexes..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20210928_0.7.0-0.8.0
  echo "Altering DB..."
  cat sqlmigrate20210928_0.7.0-0.8.0.sql | sqlite3 $DB_FILE
else
  echo "New indexes migration already done, skipping!"
fi
