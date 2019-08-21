#!/bin/sh

. ./trace.sh

serve_ots_stamp() {

  trace "Entering serve_ots_stamp()..."

  local request=${1}
  local hash=$(echo "${request}" | jq -r ".hash")
  trace "[serve_ots_stamp] hash=${hash}"
  local callbackUrl
  callbackUrl=$(echo "${request}" | jq -er ".callbackUrl")
  if [ "$?" -ne "0" ]; then
    # callbackUrl tag null, so there's no callbackUrl provided
    callbackUrl=
  else
    callbackUrl=$(echo "${callbackUrl}" | tr -d '"')
  fi
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
      errorstring=$(request_ots_stamp "${hash}" ${id_inserted})
      returncode=$?
    fi
  else
    sql "INSERT OR IGNORE INTO stamp (hash, callbackUrl) VALUES (\"${hash}\", \"${callbackUrl}\")"
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq "0" ]; then
      id_inserted=$(sql "SELECT id FROM stamp WHERE hash='${hash}'")
      trace_rc $?
      errorstring=$(request_ots_stamp "${hash}" ${id_inserted})
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

request_ots_stamp() {
  # Request the OTS server to stamp

  local hash=${1}
  local id=${2}
  local returncode
  local result
  local errorstring

  trace "[request_ots_stamp] Stamping..."
  trace "[request_ots_stamp] curl -s ${OTSCLIENT_CONTAINER}/stamp/${hash}"
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
        sql "UPDATE stamp SET requested=1 WHERE id=${id}"
        errorstring="Duplicate stamping request, hash already exists in DB and been OTS requested"
        returncode=1
      else
        # If OTS CLIENT responded with an error, it is not down, it just can't stamp it.  ABORT.
        trace "[request_ots_stamp] Stamping error: ${errorstring}"
        sql "DELETE FROM stamp WHERE id=${id}"
        returncode=1
      fi
    else
      trace "[request_ots_stamp] Stamping request sent successfully!"
      sql "UPDATE stamp SET requested=1 WHERE id=${id}"
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

serve_ots_backoffice() {
  # What we want to do here:
  # ========================
  # Re-request the unrequested calls to ots_stamp
  # Upgrade requested calls to ots_stamp that have not been called back yet
  # Call back newly upgraded stamps

  trace "Entering serve_ots_backoffice()..."

  local result
  local returncode

  # Let's fetch all the incomplete stamping request
  local callbacks=$(sql 'SELECT hash, callbackUrl, requested, upgraded, id FROM stamp WHERE NOT calledback')
  trace "[serve_ots_backoffice] callbacks=${callbacks}"

  local url
  local hash
  local requested
  local upgraded
  local id
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
    id=$(echo "${row}" | cut -d '|' -f5)
    trace "[serve_ots_backoffice] id=${id}"

    if [ "${requested}" -ne "1" ]; then
      # Re-request the unrequested calls to ots_stamp
      request_ots_stamp "${hash}" ${id}
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
            sql "UPDATE stamp SET upgraded=1 WHERE id=${id}"
            trace_rc $?

            upgraded=1
          fi
        fi
      fi
      if [ "${upgraded}" -eq "1" ]; then
        trace "[serve_ots_backoffice] upgraded!  Let's call the callback..."
        url=$(echo "${row}" | cut -d '|' -f2)
        trace "[serve_ots_backoffice] url=${url}"

        # Call back newly upgraded stamps if url provided
        if [ -n ${url} ]; then
          trace "[serve_ots_backoffice] url is not empty, now trying to call it!"

          notify_web "${url}"
          returncode=$?
          trace_rc ${returncode}

          # Even if curl executed ok, we need to make sure the http return code is also ok

          if [ "${returncode}" -eq "0" ]; then
            sql "UPDATE stamp SET calledback=1 WHERE id=${id}"
            trace_rc $?
          fi
        else
          trace "[serve_ots_backoffice] url is empty, obviously won't try to call it!"

          sql "UPDATE stamp SET calledback=1 WHERE id=${id}"
          trace_rc $?
        fi
      fi
    fi
  done
}

serve_ots_getfile() {
  trace "Entering serve_ots_getfile()..."

  local hash=${1}
  trace "[serve_ots_getfile] hash=${hash}"

  binfile_response_to_client "otsfiles/" "${hash}.ots"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

serve_ots_verify() {

  trace "Entering serve_ots_verify()..."

  local request=${1}
  local hash=$(echo "${request}" | jq ".hash" | tr -d '"')
  trace "[serve_ots_verify] hash=${hash}"
  local base64otsfile=$(echo "${request}" | jq ".base64otsfile" | tr -d '"')
  trace "[serve_ots_verify] base64otsfile=${base64otsfile}"

  local result
  local message
  local returncode

  trace "[serve_ots_verify] request_ots_verify \"${hash}\" \"${base64otsfile}\""
  result=$(request_ots_verify "${hash}" "${base64otsfile}")
  returncode=$?
  trace_rc ${returncode}

  message=$(echo ${result} | jq ".message")
  result=$(echo ${result} | jq ".result")
  result="{\"method\":\"ots_verify\",\"hash\":\"${hash}\",\"result\":${result},\"message\":${message}}"

  trace "[serve_ots_verify] result=${result}"

  # Output response to stdout before exiting with return code
  echo "${result}"

  return ${returncode}
}

request_ots_verify() {
  # Request the OTS server to verify

  local hash=${1}
  trace "[request_ots_verify] hash=${hash}"
  local base64otsfile=${2}
  trace "[request_ots_verify] base64otsfile=${base64otsfile}"
  local returncode
  local result
  local data

  # BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}
  data="{\"hash\":\"${hash}\",\"base64otsfile\":\"${base64otsfile}\"}"
  trace "[request_ots_verify] data=${data}"

  trace "[request_ots_verify] Verifying..."
  trace "[request_ots_stamp] curl -s -d \"${data}\" ${OTSCLIENT_CONTAINER}/verify"
  result=$(curl -s -d "${data}" ${OTSCLIENT_CONTAINER}/verify)
  returncode=$?
  trace_rc ${returncode}
  trace "[request_ots_verify] Verifying result=${result}"

  if [ "${returncode}" -ne 0 ]; then
    trace "[request_ots_verify] Verifying error"
  fi

  echo "${result}"
  return ${returncode}
}

serve_ots_info() {

  trace "Entering serve_ots_info()..."

  local request=${1}
  local hash
  hash=$(echo "${request}" | jq -e ".hash")
  if [ "$?" -ne "0" ]; then
    # Hash tag null, so there's no hash provided
    hash=
  else
    hash=$(echo "${hash}" | tr -d '"')
  fi
  trace "[serve_ots_info] hash=${hash}"
  local base64otsfile
  base64otsfile=$(echo "${request}" | jq -e ".base64otsfile")
  if [ "$?" -ne "0" ]; then
    # base64otsfile tag null, so there's no base64otsfile provided
    base64otsfile=
  else
    base64otsfile=$(echo "${base64otsfile}" | tr -d '"')
  fi
  trace "[serve_ots_info] base64otsfile=${base64otsfile}"

  # If file is provided, we will execute info on it
  # If file not provided, we will check for hash.ots in our folder and execute info on it
  if [ -z "${base64otsfile}" ]; then
    if [ -f otsfiles/${hash}.ots ]; then
      trace "[serve_ots_info] Constructing base64otsfile from provided hash, file otsfiles/${hash}.ots"
      base64otsfile=$(cat otsfiles/${hash}.ots | base64 | tr -d '\n')
    else
      trace "[serve_ots_info] File otsfiles/${hash}.ots does not exists!"
      echo "{\"method\":\"ots_info\",\"result\":\"error\",\"message\":\"OTS File not found\"}"
      return 1
    fi
  fi

  local result
  local message
  local returncode

  trace "[serve_ots_info] request_ots_info \"${base64otsfile}\""
  result=$(request_ots_info "${base64otsfile}")
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    result=$(echo ${result} | jq ".result")
    result="{\"method\":\"ots_info\",\"result\":\"success\",\"message\":${result}}"
  else
    result="{\"method\":\"ots_info\",\"result\":\"error\",\"message\":${result}}"
  fi

  trace "[serve_ots_info] result=${result}"

  # Output response to stdout before exiting with return code
  echo "${result}"

  return ${returncode}
}

request_ots_info() {
  # Request the OTS server to verify

  local base64otsfile=${1}
  trace "[request_ots_info] base64otsfile=${base64otsfile}"
  local returncode
  local result
  local data

  # BODY {"base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}
  data="{\"base64otsfile\":\"${base64otsfile}\"}"
  trace "[request_ots_info] data=${data}"

  trace "[request_ots_info] Parsing..."
  trace "[request_ots_info] curl -s -d \"${data}\" ${OTSCLIENT_CONTAINER}/info"
  result=$(curl -s -d "${data}" ${OTSCLIENT_CONTAINER}/info)
  returncode=$?
  trace_rc ${returncode}
  trace "[request_ots_info] OTS info result=${result}"

  if [ "${returncode}" -ne 0 ]; then
    trace "[request_ots_info] OTS info error"
  fi

  echo "${result}"
  return ${returncode}
}
