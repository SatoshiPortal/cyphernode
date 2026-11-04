#!/bin/sh

. ./trace.sh

# Adds the Ark (barkd) tables. Every statement is idempotent.

SCRIPT_NAME="sqlmigrate20261103_0.9.0-0.9.0_ark.sh"

trace "[$SCRIPT_NAME] Applying cyphernode-ark.postgresql..."
psql -qAtX -h postgres -U cyphernode -v ON_ERROR_STOP=1 -f cyphernode-ark.postgresql
returncode=$?
trace_rc ${returncode}
exit ${returncode}
