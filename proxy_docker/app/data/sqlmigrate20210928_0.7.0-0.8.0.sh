#!/bin/sh

echo "Checking for rawtx database support in DB..."
if [ ! -e ${DB_FILE}_rawtx ]; then
  # rawtx database not found
  echo "Migrating database for rawtx database support..."
  echo "Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20210928_0.7.0-0.8.0
  echo "Altering DB..."
  cat sqlmigrate20210928_0.7.0-0.8.0.sql | sqlite3 $DB_FILE
  echo "Creating new DB..."
  cat rawtx.sql | sqlite3 ${DB_FILE}_rawtx
  echo "Inserting table in new DB..."
  sqlite3 -cmd ".timeout 25000" ${DB_FILE} "ATTACH DATABASE \"${DB_FILE}_rawtx\" AS other; INSERT INTO other.rawtx SELECT * FROM tx; DETACH other;"
else
  echo "rawtx database support migration already done, skipping!"
fi
