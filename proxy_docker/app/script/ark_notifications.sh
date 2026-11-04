#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./ark_callbacks.sh

# Long-polls barkd's notification stream and turns successful movements into
# callbacks. The cursor is kept in cyphernode_props so a restart resumes where
# it stopped. barkd keeps ten minutes of notifications; anything older is
# picked up by ark_manage_missed from proxycron.

ark_cursor_get() {
  sql "SELECT value FROM cyphernode_props WHERE property='ark_last_pushed_at'"
}

ark_cursor_set() {
  sql "UPDATE cyphernode_props SET value='$(sql_quote "${1}")' WHERE property='ark_last_pushed_at'" > /dev/null
}

ark_wait_notifications() {
  trace "Entering ark_wait_notifications()..."

  local since=${1}
  local path response returncode notifications notification kind movement last_pushed_at

  path="/notifications/wait"
  [ -n "${since}" ] && path="${path}?since=$(printf '%s' "${since}" | jq -sRr @uri)"

  response=$(BARKD_TIMEOUT=120 barkd_call GET "${path}")
  returncode=$?
  if [ "${returncode}" -ne 0 ]; then
    trace "[ark_wait_notifications] wait failed with ${returncode}"
    return 1
  fi

  notifications=$(printf '%s' "${response}" | jq -c '.notifications[]?')
  local IFS="
"
  for notification in ${notifications}; do
    kind=$(printf '%s' "${notification}" | jq -r '.type')
    case "${kind}" in
      movement-created|movement-updated)
        movement=$(printf '%s' "${notification}" | jq -c '.movement')
        ark_process_movement "${movement}"
        ;;
      channel-lagging)
        trace "[ark_wait_notifications] stream lagged, running catch-up"
        ark_manage_missed
        ;;
    esac
  done
  unset IFS

  last_pushed_at=$(printf '%s' "${response}" | jq -r '.last_pushed_at // empty')
  [ -n "${last_pushed_at}" ] && ark_cursor_set "${last_pushed_at}"

  [ -n "${notifications}" ] && ark_do_callbacks

  return 0
}

. ./ark_manage_missed.sh

# On start, catch up first so a long outage is covered before resuming the stream.
ark_manage_missed

while :
do
  since=$(ark_cursor_get)
  trace "[ark_notifications] since=${since}"
  if ark_wait_notifications "${since}"; then
    sleep 1
  else
    # barkd not ready or unreachable
    sleep 10
  fi
done
