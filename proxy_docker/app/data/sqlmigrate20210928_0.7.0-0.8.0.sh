#!/bin/sh

. ./trace.sh

trace "[sqlmigrate20210928_0.7.0-0.8.0.sh] Checking for new indexes in DB..."
sqlite3 $DB_FILE ".indexes" | grep "idx_watching_watching" > /dev/null
if [ "$?" -eq "1" ]; then
  # idx_watching_watching index not found
  trace "[sqlmigrate20210928_0.7.0-0.8.0.sh] Migrating database with new indexes..."
  trace "[sqlmigrate20210928_0.7.0-0.8.0.sh] Backing up current DB..."
  cp $DB_FILE $DB_FILE-sqlmigrate20210928_0.7.0-0.8.0
  trace "[sqlmigrate20210928_0.7.0-0.8.0.sh] Altering DB..."
  cat sqlmigrate20210928_0.7.0-0.8.0.sql | sqlite3 $DB_FILE
  returncode=$?
  trace_rc ${returncode}
  exit ${returncode}
else
  trace "[sqlmigrate20210928_0.7.0-0.8.0.sh] New indexes migration already done, skipping!"
fi
