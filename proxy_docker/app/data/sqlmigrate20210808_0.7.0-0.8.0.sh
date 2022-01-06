#!/bin/sh

. ./trace.sh

trace "[sqlmigrate20210808_0.7.0-0.8.0.sh] Checking for labels for watched addresses support in DB..."
count=$(sqlite3 $DB_FILE "select count(*) from pragma_table_info('watching') where name='label'")
if [ "${count}" -eq "0" ]; then
  # label not there, we have to migrate
  trace "[sqlmigrate20210808_0.7.0-0.8.0.sh] Migrating database for labels for watched addresses support..."
  trace "[sqlmigrate20210808_0.7.0-0.8.0.sh] Backing up current DB..."
  cp  $DB_FILE $DB_FILE-sqlmigrate20210808_0.7.0-0.8.0
  trace "[sqlmigrate20210808_0.7.0-0.8.0.sh] Altering DB..."
  cat sqlmigrate20210808_0.7.0-0.8.0.sql | sqlite3 $DB_FILE
  returncode=$?
  trace_rc ${returncode}
  exit ${returncode}
else
  trace "[sqlmigrate20210808_0.7.0-0.8.0.sh] Database labels for watched addresses support migration already done, skipping!"
fi
