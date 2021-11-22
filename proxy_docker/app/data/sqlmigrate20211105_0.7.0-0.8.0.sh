#!/bin/sh

date
echo "Waiting for postgres to be ready..."
(while true ; do psql -h postgres -U cyphernode -c "select 1;" ; [ "$?" -eq "0" ] && break ; sleep 10; done) &
wait

echo "Checking if postgres is setup..."
psql -h postgres -U cyphernode -c "\d" | grep "cyphernode_props" > /dev/null
if [ "$?" -eq "1" ]; then
  # if cyphernode_props table doesn't exist, it's probably because database hasn't been setup yet
  echo "Creating postgres database..."
  psql -h postgres -f cyphernode.postgresql -U cyphernode

  date
  echo "Extracting and converting sqlite3 data..."
  date
  cat sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extract.sql | sqlite3 $DB_FILE
  mv sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql ${DB_PATH}/
  sed -ie 's/^\(INSERT.*\);$/\1 ON CONFLICT DO NOTHING;/g' ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql

  date
  echo "...appending postgresql sequences..."
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

  date
  echo "Importing sqlite3 data into postgresql..."
  psql -h postgres -f ${DB_PATH}/sqlmigrate20211105_0.7.0-0.8.0_sqlite3-extracted-data.sql -U cyphernode
  date
else
  echo "New indexes migration already done, skipping!"
fi
