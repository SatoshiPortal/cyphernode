#!/bin/sh

. ./trace.sh

# Let's drop uniqueness constraint on unblinded_address in elements_watching
#

SCRIPT_NAME="sqlmigrate20250212_0.8.0-0.9.0.sh"

trace "[$SCRIPT_NAME] Checking if unique constraint 'elements_watching_unblinded_address_key' is in the table ..."
table_descr=$(psql -qAtX -h postgres -U cyphernode -c "\di")
unique_idx=$(echo $table_descr | grep 'elements_watching_unblinded_address_key')
returncode=$?
if [ -n "$unique_idx" ]; then

  SQL_ST="ALTER TABLE elements_watching DROP CONSTRAINT elements_watching_unblinded_address_key"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  SQL_ST="CREATE INDEX idx_elements_watching_unblinded_address ON elements_watching (unblinded_address)"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  [ "${returncode}" -eq "0" ] || exit ${returncode}

else
  trace "[$SCRIPT_NAME] Unique index elements_watching_unblinded_address_key already dropped, skipping!"
fi
