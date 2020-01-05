#!/bin/sh

. ./trace.sh

web() {
  trace "Entering web()..."

  local msg=${1}
  local url
  local body
  local torbypass
  local returncode
  local response
  local result

  trace "[web] msg=${msg}"
  url=$(echo ${msg} | jq ".url")
  trace "[web] url=${url}"

  body=$(echo ${msg} | jq -e ".body")
  # jq -e will have a return code of 1 if the supplied tag is null.
  if [ "$?" -eq "0" ]; then
    # body tag not null, so it's a POST
    # The body field has been based-64 to avoid dealing with escaping special chars
    body=$(echo "${body}" | base64 -d)
    trace "[web] body=${body}"
  else
    body=
    trace "[web] no body, GET request"
  fi

  torbypass=$(echo ${msg} | jq -e ".torbypass")
  # jq -e will have a return code of 1 if the supplied tag is null.
  if [ "$?" -ne "0" ]; then
    # torbypass tag null
    torbypass=false
  fi
  trace "[web] torbypass=${torbypass}"

  response=$(curl_it "${url}" "${body}", "${torbypass}")
  returncode=$?
  trace_rc ${returncode}

  echo "${response}"

  return ${returncode}
}

curl_it() {
  trace "Entering curl_it()..."

  local url=$(echo "${1}" | tr -d '"')
  local data=${2}
  local torbypass=${3}
  local returncode
  local response
  local rnd=$(dd if=/dev/urandom bs=5 count=1 | xxd -pc 5)

  if [ "${torbypass}" = "true" ]; then
    torbypass=""
  else
    torbypass="-K curlcfg"
  fi

  if [ -n "${data}" ]; then
    trace "[curl_it] curl ${torbypass} -o webresponse-${rnd} -m 20 -w \"%{http_code}\" -H \"Content-Type: application/json\" -H \"X-Forwarded-Proto: https\" -d \"${data}\" -k ${url}"
    rc=$(curl ${torbypass} -o webresponse-${rnd} -m 20 -w "%{http_code}" -H "Content-Type: application/json" -H "X-Forwarded-Proto: https" -d "${data}" -k ${url})
    returncode=$?
  else
    trace "[curl_it] curl ${torbypass} -o webresponse-$$ -m 20 -w \"%{http_code}\" -k ${url}"
    rc=$(curl ${torbypass} -o webresponse-${rnd} -m 20 -w "%{http_code}" -k ${url})
    returncode=$?
  fi
  trace "[curl_it] HTTP return code=${rc}"
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    response=$(cat webresponse-${rnd} | base64 | tr -d '\n' ; rm webresponse-${rnd})
  else
    response=
  fi
  # When curl is unable to connect, http_code is "000" which is not a valid JSON number
  [ "${rc}" -eq "0" ] && rc=0
  response="{\"curl_code\":${returncode},\"http_code\":${rc},\"body\":\"${response}\"}"

  echo "${response}"

  if [ "${returncode}" -eq "0" ]; then
    if [ "${rc}" -lt "400" ]; then
      return 0
    else
      return ${rc}
    fi
  else
    return ${returncode}
  fi
}
