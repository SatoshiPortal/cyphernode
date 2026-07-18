#!/bin/sh

. ./trace.sh

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
version=$(psql -qAtX -h postgres -U cyphernode -c "select value from cyphernode_props where property='version'")
returncode=$?
if [ "${version}" != "0.2" ]; then
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
select setval('cyphernode_props_id_seq', (SELECT MAX(id) FROM cyphernode_props));
select setval('ln_invoice_id_seq', (SELECT MAX(id) FROM ln_invoice));
select setval('recipient_id_seq', (SELECT MAX(id) FROM recipient));
select setval('stamp_id_seq', (SELECT MAX(id) FROM stamp));
select setval('tx_id_seq', (SELECT MAX(id) FROM tx));
select setval('watching_by_pub32_id_seq', (SELECT MAX(id) FROM watching_by_pub32));
select setval('watching_by_txid_id_seq', (SELECT MAX(id) FROM watching_by_txid));
select setval('watching_id_seq', (SELECT MAX(id) FROM watching));
select setval('batcher_id_seq', (SELECT MAX(id) FROM batcher));
update cyphernode_props set value='0.2' where property='version';
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

trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Checking if postgres is set up with elements..."
psql -h postgres -U cyphernode -c "\d" | grep "elements_tx" > /dev/null
if [ "$?" -eq "1" ]; then
  # if elements_tx table doesn't exist, let's migrate elements tables from sqlite3 to postgres!
  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Creating postgres database..."
  psql -h postgres -f cyphernode-elements.postgresql -U cyphernode
  returncode=$?
  trace_rc ${returncode}
  [ "${returncode}" -eq "0" ] || exit ${returncode}

  # Check if elements was in sqlite3 db...
  echo "Checking for elements support in SQLite3 DB..."
  sqlite3 $DB_FILE ".tables" | grep "elements_tx" > /dev/null
  if [ "$?" -eq "0" ]; then
    # elements_tx there, elements tables are there!
    trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Extracting and converting sqlite3 elements data..."
    cat sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extract_elements.sql | sqlite3 $DB_FILE
    returncode=$?
    trace_rc ${returncode}
    [ "${returncode}" -eq "0" ] || exit ${returncode}

    trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Creating elements import file for postgres..."
    mv sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data-elements.sql ${DB_PATH}/
    sed -ie 's/^\(INSERT.*\);$/\1 ON CONFLICT DO NOTHING;/g' ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data-elements.sql

    echo "
select setval('elements_recipient_id_seq',  (SELECT MAX(id) FROM elements_recipient));
select setval('elements_tx_id_seq',  (SELECT MAX(id) FROM elements_tx));
select setval('elements_watching_by_pub32_id_seq',  (SELECT MAX(id) FROM elements_watching_by_pub32));
select setval('elements_watching_by_txid_id_seq',  (SELECT MAX(id) FROM elements_watching_by_txid));
select setval('elements_watching_id_seq',  (SELECT MAX(id) FROM elements_watching));
commit;
" >> ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data-elements.sql

    trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] Importing sqlite3 elements data into postgresql..."
    psql -v ON_ERROR_STOP=on -h postgres -f ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data-elements.sql -U cyphernode
    returncode=$?
    trace_rc ${returncode}
    [ "${returncode}" -eq "0" ] || exit ${returncode}
  fi
else
  trace "[sqlmigrate20211105_0.7.0-0.8.0.sh] PostgreSQL database already loaded with elements tables, skipping!"
fi
