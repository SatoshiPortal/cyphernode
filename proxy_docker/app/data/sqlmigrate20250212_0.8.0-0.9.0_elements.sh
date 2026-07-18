#!/bin/sh

. ./trace.sh

# Replace the obsolete unblinded-address uniqueness constraint with a regular
# lookup index.  Keep DROP and CREATE in one transaction.

SCRIPT_NAME="sqlmigrate20250212_0.8.0-0.9.0_elements.sh"

constraint_exists=$(psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "SELECT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'elements_watching_unblinded_address_key' AND conrelid = 'elements_watching'::regclass);")
returncode=$?
trace_rc ${returncode}
[ "${returncode}" -eq 0 ] || exit ${returncode}

index_def=$(psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "SELECT indexdef FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_elements_watching_unblinded_address';")
returncode=$?
trace_rc ${returncode}
[ "${returncode}" -eq 0 ] || exit ${returncode}

index_is_current=false
case "${index_def}" in
  "CREATE INDEX "*"(unblinded_address)"*) index_is_current=true ;;
esac

if [ "${constraint_exists}" = "t" ] || ! ${index_is_current}; then
  trace "[$SCRIPT_NAME] Replacing the obsolete constraint transactionally"
  SQL_ST="BEGIN; ALTER TABLE elements_watching DROP CONSTRAINT IF EXISTS elements_watching_unblinded_address_key; DROP INDEX IF EXISTS idx_elements_watching_unblinded_address; CREATE INDEX idx_elements_watching_unblinded_address ON elements_watching (unblinded_address); COMMIT;"
  psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "${SQL_ST}"
  returncode=$?
  trace_rc ${returncode}
  [ "${returncode}" -eq 0 ] || exit ${returncode}
else
  trace "[$SCRIPT_NAME] Constraint already removed and lookup index present, skipping!"
fi
