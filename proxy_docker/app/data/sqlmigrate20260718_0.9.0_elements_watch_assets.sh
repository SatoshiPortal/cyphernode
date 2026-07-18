#!/bin/sh

. ./trace.sh

# Align the existing Elements watch identity with the fresh-install schema.

SCRIPT_NAME="sqlmigrate20260718_0.9.0_elements_watch_assets.sh"

watch_index_def=$(psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "SELECT indexdef FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_elements_watching_01';")
returncode=$?
trace_rc ${returncode}
[ "${returncode}" -eq 0 ] || exit ${returncode}

replace_watch=false

case "${watch_index_def}" in
  "CREATE UNIQUE INDEX "*"(address, COALESCE(callback0conf"*"COALESCE(callback1conf"*"COALESCE(watching_assetid"*) ;;
  *) replace_watch=true ;;
esac

if ! ${replace_watch}; then
  trace "[$SCRIPT_NAME] Elements watch index already has the required definition, skipping!"
  exit 0
fi

SQL_ST="BEGIN; DROP INDEX IF EXISTS idx_elements_watching_01; CREATE UNIQUE INDEX idx_elements_watching_01 ON elements_watching (address, COALESCE(callback0conf, ''), COALESCE(callback1conf, ''), COALESCE(watching_assetid, '')); COMMIT;"

trace "[$SCRIPT_NAME] Replacing outdated Elements watch index transactionally"
psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "${SQL_ST}"
returncode=$?
trace_rc ${returncode}
[ "${returncode}" -eq 0 ] || exit ${returncode}
