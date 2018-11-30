#!/bin/sh

. ./trace.sh

serve_ots_stamp()
{

  trace "Entering serve_ots_stamp()..."

  local request=${1}
  local hash=$(echo "${request}" | jq ".hash" | tr -d '"')
  trace "[serve_ots_stamp] hash=${hash}"
  local callbackUrl=$(echo "${request}" | jq ".callbackUrl" | tr -d '"')
  trace "[serve_ots_stamp] callbackUrl=${callbackUrl}"

  local result
  local returncode
  local errorstring
  local id_inserted
  local requested
  local row

  # Already requested?
  row=$(sql "SELECT id, requested FROM stamp WHERE hash='${hash}'")
  trace "[serve_ots_stamp] row=${row}"

  if [ -n "${row}" ]; then
    # Hash exists in DB...
    trace "[serve_ots_stamp] Hash already exists in DB."

    requested=$(echo "${row}" | cut -d '|' -f2)
    trace "[serve_ots_stamp] requested=${requested}"
    id_inserted=$(echo "${row}" | cut -d '|' -f1)
    trace "[serve_ots_stamp] id_inserted=${id_inserted}"

    if [ "${requested}" -eq "1" ]; then
      # Stamp already requested
      trace "[serve_ots_stamp] Stamp already requested"
      errorstring="Duplicate stamping request, hash already exists in DB and been OTS requested"
      returncode=1
    else
      errorstring=$(request_ots_stamp "${hash}")
      returncode=$?
    fi
  else
    sql "INSERT OR IGNORE INTO stamp (hash, callbackUrl) VALUES (\"${hash}\", \"${callbackUrl}\")"
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq "0" ]; then
      id_inserted=$(sql "SELECT id FROM stamp WHERE hash='${hash}'")
      trace_rc $?
      errorstring=$(request_ots_stamp "${hash}")
      returncode=$?
      trace_rc ${returncode}
    else
      trace "[serve_ots_stamp] Stamp request could not be inserted in DB"
      errorstring="Stamp request could not be inserted in DB, please retry later"
      returncode=1
    fi
  fi

  result="{\"method\":\"ots_stamp\",\"hash\":\"${hash}\",\"id\":\"${id_inserted}\",\"result\":\""

  if [ "${returncode}" -eq "0" ]; then
    result="${result}success\"}"
  else
    result="${result}error\",\"error\":\"${errorstring}\"}"
  fi

  trace "[serve_ots_stamp] result=${result}"

  # Output response to stdout before exiting with return code
  echo "${result}"

  return ${returncode}
}

request_ots_stamp()
{
  # Request the OTS server to stamp

  local hash=${1}
  local returncode
  local result
  local errorstring

  trace "[request_ots_stamp] Stamping..."
  result=$(curl -s ${OTSCLIENT_CONTAINER}/stamp/${hash})
  returncode=$?
  trace_rc ${returncode}
  trace "[request_ots_stamp] Stamping result=${result}"

  if [ "${returncode}" -eq 0 ]; then
    # jq -e will have a return code of 1 if the supplied tag is null.
    errorstring=$(echo "${result}" | tr '\r\n' ' ' | jq -e ".error")
    if [ "$?" -eq "0" ]; then
      # Error tag not null, so there's an error

      errorstring=$(echo "${errorstring}" | tr -d '"')

      # If the error message is "Already exists"
      trace "[request_ots_stamp] grepping 'already exists'..."
      echo "${result}" | grep "already exists" > /dev/null
      returncode=$?
      trace_rc ${returncode}

      if [ "${returncode}" -eq "0" ]; then
        # "already exists" found, let's try updating DB again
        trace "[request_ots_stamp] was already requested to the OTS server... let's update the DB, looks like it didn't work on first try"
        sql "UPDATE stamp SET requested=1 WHERE hash='${hash}'"
        errorstring="Duplicate stamping request, hash already exists in DB and been OTS requested"
        returncode=1
      else
        # If OTS CLIENT responded with an error, it is not down, it just can't stamp it.  ABORT.
        trace "[request_ots_stamp] Stamping error: ${errorstring}"
        sql "DELETE FROM stamp WHERE hash='${hash}'"
        returncode=1
      fi
    else
      trace "[request_ots_stamp] Stamping request sent successfully!"
      sql "UPDATE stamp SET requested=1 WHERE hash='${hash}'"
      errorstring=""
      returncode=0
    fi
  else
    trace "[request_ots_stamp] Stamping error, will retry later: ${errorstring}"
    errorstring=""
    returncode=0
  fi

  echo "${errorstring}"
  return ${returncode}
}

serve_ots_backoffice()
{
  # What we want to do here:
  # ========================
  # Re-request the unrequested calls to ots_stamp
  # Upgrade requested calls to ots_stamp that have not been called back yet
  # Call back newly upgraded stamps

  trace "Entering serve_ots_backoffice()..."

  local result
  local returncode

  # Let's fetch all the incomplete stamping request
  local callbacks=$(sql 'SELECT hash, callbackUrl, requested, upgraded FROM stamp WHERE NOT calledback')
  trace "[serve_ots_backoffice] callbacks=${callbacks}"

  local url
  local hash
  local requested
  local upgraded
  local IFS=$'\n'
  for row in ${callbacks}
  do
    trace "[serve_ots_backoffice] row=${row}"
    hash=$(echo "${row}" | cut -d '|' -f1)
    trace "[serve_ots_backoffice] hash=${hash}"
    requested=$(echo "${row}" | cut -d '|' -f3)
    trace "[serve_ots_backoffice] requested=${requested}"
    upgraded=$(echo "${row}" | cut -d '|' -f4)
    trace "[serve_ots_backoffice] upgraded=${upgraded}"

    if [ "${requested}" -ne "1" ]; then
      # Re-request the unrequested calls to ots_stamp
      request_ots_stamp "${hash}"
      returncode=$?
    else
      if [ "${upgraded}" -ne "1" ]; then
        # Upgrade requested calls to ots_stamp that have not been called back yet
        trace "[serve_ots_backoffice] curl -s ${OTSCLIENT_CONTAINER}/upgrade/${hash}"
        result=$(curl -s ${OTSCLIENT_CONTAINER}/upgrade/${hash})
        returncode=$?
        trace_rc ${returncode}
        trace "[serve_ots_backoffice] result=${result}"

        if [ "${returncode}" -eq 0 ]; then
          # CURL success... let's see if error in response
          errorstring=$(echo "${result}" | tr '\r\n' ' ' | jq -e ".error")
          if [ "$?" -eq "0" ]; then
            # Error tag not null, so there's an error
            trace "[serve_ots_backoffice] not upgraded!"

            upgraded=0
          else
            # No failure, upgraded
            trace "[serve_ots_backoffice] just upgraded!"
            sql "UPDATE stamp SET upgraded=1 WHERE hash=\"${hash}\""
            trace_rc $?

            upgraded=1
          fi
        fi
      fi
      if [ "${upgraded}" -eq "1" ]; then
        trace "[serve_ots_backoffice] upgraded!  Let's call the callback..."
        url=$(echo "${row}" | cut -d '|' -f2)
        trace "[serve_ots_backoffice] url=${url}"

        # Call back newly upgraded stamps
        curl -H "X-Forwarded-Proto: https" ${url}
        returncode=$?
        trace_rc ${returncode}

        if [ "${returncode}" -eq "0" ]; then
          sql "UPDATE stamp SET calledback=1 WHERE hash=\"${hash}\""
          trace_rc $?
        fi
      fi
    fi
  done
}

serve_ots_getfile()
{
  trace "Entering serve_ots_getfile()..."

  local hash=${1}
  trace "[serve_ots_getfile] hash=${hash}"

  file_response_to_client "/otsfiles/" "${hash}.ots"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}
