#!/bin/sh

. ./trace.sh

web() {
  trace "Entering web()..."

  local msg=${1}
  local url
  local body
  local returncode
  local http_code
  local result

  trace "[web] msg=${msg}"
  url=$(echo ${msg} | jq ".url")
  trace "[web] url=${url}"

  body=$(echo ${msg} | jq -e ".body")
  # jq -e will have a return code of 1 if the supplied tag is null.
  if [ "$?" -eq "0" ]; then
    # body tag not null, so it's a POST
    trace "[web] body=${body}"
  else
    body=
    trace "[web] no body, GET request"
  fi

  http_code=$(curl_it "${url}" "${body}")
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    # {"result":"success", "response":"<html></html>"}
    result="success"
  else
    # {"result":"error", "response":"<html></html>"}
    result="error"
  fi

  echo "{\"result\":\"${result}\",\"http_code\":\"${http_code}\"}"

  return ${returncode}
}

curl_it() {
  trace "Entering curl_it()..."

  local url=$(echo "${1}" | tr -d '"')
  local data=${2}
  local returncode

  if [ -n "${data}" ]; then
    trace "[curl_it] curl -o /dev/null -w \"%{http_code}\" -H \"Content-Type: application/json\" -H \"X-Forwarded-Proto: https\" -d ${data} ${url}"
    rc=$(curl -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -H "X-Forwarded-Proto: https" -d ${data} ${url})
    returncode=$?
  else
    trace "[curl_it] curl -o /dev/null -w \"%{http_code}\" ${url}"
    rc=$(curl -o /dev/null -w "%{http_code}" ${url})
    returncode=$?
  fi
  trace "[curl_it] HTTP return code=${rc}"
  trace_rc ${returncode}

  echo "${rc}"

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
