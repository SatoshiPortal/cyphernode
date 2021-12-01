#!/bin/sh

. ./trace.sh

trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Waiting for PostgreSQL to be ready..."
while [ ! -f "/container_monitor/postgres_ready" ]; do echo "PostgreSQL not ready" ; sleep 10 ; done
trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] PostgreSQL ready!"

trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Checking if postgres is set up..."
psql -h postgres -U cyphernode -c "\d" | grep "cyphernode_props" > /dev/null
if [ "$?" -eq "1" ]; then
  # if cyphernode_props table doesn't exist, it's probably because database hasn't been setup yet
  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Creating postgres database..."
  psql -h postgres -f cyphernode.postgresql -U cyphernode
  returncode=$?
  trace_rc ${returncode}
  [ "${returncode}" -eq "0" ] || exit ${returncode}
else
  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] PostgreSQL database already created, skipping!"
fi

trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Checking if postgres is loaded/imported..."
lastval=$(psql -qAtX -h postgres -U cyphernode -c "select last_value from pg_sequences where sequencename='cyphernode_props_id_seq'")
returncode=$?
if [ -z "${lastval}" ] || [ "${lastval}" -lt "2" ]; then
  # if cyphernode_props_id_seq isn't set, it's probably because database hasn't been loaded/imported yet
  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Extracting and converting sqlite3 data..."
  cat sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extract.sql | sqlite3 $DB_FILE
  returncode=$?
  trace_rc ${returncode}
  [ "${returncode}" -eq "0" ] || exit ${returncode}

  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Creating import file for postgres..."
  mv sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql ${DB_PATH}/
  sed -ie 's/^\(INSERT.*\);$/\1 ON CONFLICT DO NOTHING;/g' ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql

  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Appending postgresql sequence creation..."
  echo "
select setval('cyphernode_props_id_seq',  (SELECT MAX(id) FROM cyphernode_props));
select setval('ln_invoice_id_seq',  (SELECT MAX(id) FROM ln_invoice));
select setval('recipient_id_seq',  (SELECT MAX(id) FROM recipient));
select setval('stamp_id_seq',  (SELECT MAX(id) FROM stamp));
select setval('tx_id_seq',  (SELECT MAX(id) FROM tx));
select setval('watching_by_pub32_id_seq',  (SELECT MAX(id) FROM watching_by_pub32));
select setval('watching_by_txid_id_seq',  (SELECT MAX(id) FROM watching_by_txid));
select setval('watching_id_seq',  (SELECT MAX(id) FROM watching));
select setval('batcher_id_seq',  (SELECT MAX(id) FROM batcher));
commit;
" >> ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql

  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Importing sqlite3 data into postgresql..."
  psql -v ON_ERROR_STOP=on -h postgres -f ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql -U cyphernode
  returncode=$?
  trace_rc ${returncode}
  [ "${returncode}" -eq "0" ] || exit ${returncode}
else
  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] PostgreSQL database already loaded, skipping!"
fi
