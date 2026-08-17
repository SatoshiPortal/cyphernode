#!/bin/sh

. ./trace.sh

# Replace the txid-watch index only when its definition is still the nullable
# legacy form.  The DDL is one transaction so a failed CREATE restores the old
# index instead of leaving the table without its uniqueness guarantee.

SCRIPT_NAME="sqlmigrate20250311_0.8.0-0.9.0_elements.sh"

trace "[$SCRIPT_NAME] Checking index definition for idx_elements_watching_by_txid_1x..."
index_def=$(psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "SELECT indexdef FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_elements_watching_by_txid_1x';")
returncode=$?
trace_rc ${returncode}
[ "${returncode}" -eq 0 ] || exit ${returncode}

case "${index_def}" in
  "CREATE UNIQUE INDEX "*"(txid, COALESCE(callback1conf"*"COALESCE(callbackxconf"*)
    trace "[$SCRIPT_NAME] Index already has the required null-safe definition, skipping!"
    ;;
  *)
    # The nullable legacy index allowed repeated registrations whenever either
    # callback was NULL.  Keep the newest state for each semantic subscription
    # before installing the null-safe uniqueness rule.
    SQL_ST="BEGIN; WITH duplicate_watches AS (SELECT id, ROW_NUMBER() OVER (PARTITION BY txid, COALESCE(callback1conf, ''), COALESCE(callbackxconf, '') ORDER BY inserted_ts DESC NULLS LAST, id DESC) AS duplicate_rank FROM elements_watching_by_txid WHERE txid IS NOT NULL) DELETE FROM elements_watching_by_txid AS watch USING duplicate_watches AS duplicate WHERE watch.id=duplicate.id AND duplicate.duplicate_rank>1; DROP INDEX IF EXISTS idx_elements_watching_by_txid_1x; CREATE UNIQUE INDEX idx_elements_watching_by_txid_1x ON elements_watching_by_txid (txid, COALESCE(callback1conf, ''), COALESCE(callbackxconf, '')); COMMIT;"
    trace "[$SCRIPT_NAME] Replacing idx_elements_watching_by_txid_1x transactionally"
    psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "${SQL_ST}"
    returncode=$?
    trace_rc ${returncode}
    [ "${returncode}" -eq 0 ] || exit ${returncode}
    ;;
esac
