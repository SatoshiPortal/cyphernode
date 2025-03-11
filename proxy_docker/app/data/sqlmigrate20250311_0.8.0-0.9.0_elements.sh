#!/bin/sh

. ./trace.sh

# Let's replace uniqueness constraint on idx_elements_watching_by_txid_1x in elements_watching_by_txid

SCRIPT_NAME="sqlmigrate20250311_0.8.0-0.9.0_elements.sh"

trace "[$SCRIPT_NAME] Checking if index 'idx_elements_watching_by_txid_1x' exists..."
table_descr=$(psql -qAtX -h postgres -U cyphernode -c "SELECT 1 FROM pg_indexes WHERE indexname = 'idx_elements_watching_by_txid_1x';")
if [ -n "$table_descr" ]; then
  SQL_ST="DROP INDEX idx_elements_watching_by_txid_1x"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  SQL_ST="CREATE INDEX idx_elements_watching_by_txid_1x ON elements_watching_by_txid (txid, COALESCE(callback1conf, ''), COALESCE(callbackxconf, ''))"
  trace "[$SCRIPT_NAME] $SQL_ST"
  psql -qAtX -h postgres -U cyphernode -c "$SQL_ST"
  returncode=$?
  trace_rc ${returncode}

  [ "${returncode}" -eq "0" ] || exit ${returncode}
else
  trace "[$SCRIPT_NAME] Index idx_elements_watching_by_txid_1x doesn't exist, skipping!"
fi