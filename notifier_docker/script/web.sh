#!/bin/sh

. ./trace.sh

web() {
  trace "Entering web()..."

  local msg=${1}
  local url
  local body
  local tor
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

  tor=$(echo ${msg} | jq -e ".tor")
  # jq -e will have a return code of 1 if the supplied tag is null.
  if [ "$?" -ne "0" ]; then
    # tor tag null
    tor=false
  fi
  trace "[web] tor=${tor}"

  response=$(curl_it "${url}" "${body}" "${tor}")
  returncode=$?
  trace_rc ${returncode}

  echo "${response}"

  return ${returncode}
}

curl_it() {
  trace "Entering curl_it()..."

  local url=$(echo "${1}" | tr -d '"')
  local data=${2}
  local tor=${3}
  local returncode
  local response
  local rnd=$(dd if=/dev/urandom bs=5 count=1 | xxd -pc 5)

  if [ "${tor}" = "true" ] && [ -n "${TOR_HOST}" ]; then
    # If we want to use tor and the tor host config exists
    tor="--socks5-hostname ${TOR_HOST}:${TOR_PORT}"
  else
    tor=""
  fi

  if [ -n "${data}" ]; then
    trace "[curl_it] curl ${tor} -o webresponse-${rnd} -m 20 -w \"%{http_code}\" -H \"Content-Type: application/json\" -H \"X-Forwarded-Proto: https\" -d \"${data}\" -k ${url}"
    rc=$(curl ${tor} -o webresponse-${rnd} -m 20 -w "%{http_code}" -H "Content-Type: application/json" -H "X-Forwarded-Proto: https" -d "${data}" -k ${url})
    returncode=$?
  else
    trace "[curl_it] curl ${tor} -o webresponse-$$ -m 20 -w \"%{http_code}\" -k ${url}"
    rc=$(curl ${tor} -o webresponse-${rnd} -m 20 -w "%{http_code}" -k ${url})
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
