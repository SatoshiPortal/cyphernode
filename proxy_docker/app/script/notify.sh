#!/bin/sh

. ./trace.sh

notify_web() {
  trace "Entering notify_web()..."

  local url=${1}

  # Let's encode the body to base64 so we won't have to escape the special chars...
  local body=$(echo "${2}" | base64 | tr -d '\n')

  local returncode
  local response
  local http_code

  trace "[notify_web] mosquitto_rr -h broker -W 5 -t notifier -e \"response/$$\" -m \"{\"response-topic\":\"response/$$\",\"cmd\":\"web\",\"url\":\"${url}\",\"body\":\"${body}\"}\""
  response=$(mosquitto_rr -h broker -W 5 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"web\",\"url\":\"${url}\",\"body\":\"${body}\"}")
  returncode=$?
  trace_rc ${returncode}

  trace "[notify_web] response=${response}"
  http_code=$(echo "${response}" | jq ".http_code" | tr -d '"')
  trace "[notify_web] http_code=${http_code}"

  if [ "${returncode}" -eq "0" ]; then
    if [ "${http_code}" -lt "400" ]; then
      return 0
    else
      return ${http_code}
    fi
  else
    return ${returncode}
  fi

}