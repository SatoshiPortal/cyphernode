#!/bin/sh

. ./trace.sh

notify_web() {
  trace "Entering notify_web()..."

  local url=${1}
  local tor=${3}

  # Let's encode the body to base64 so we won't have to escape the special chars...
  local body=$(echo "${2}" | base64 | tr -d '\n')

  local returncode
  local response
  local http_code
  local curl_code
  local msg

  if [ -n "${tor}" ]; then
    msg="{\"response-topic\":\"response/$$\",\"cmd\":\"web\",\"url\":\"${url}\",\"body\":\"${body}\",\"tor\":${tor}}"
  else
    msg="{\"response-topic\":\"response/$$\",\"cmd\":\"web\",\"url\":\"${url}\",\"body\":\"${body}\"}"
  fi

  # We use the pid as the response-topic, so there's no conflict in responses.
  trace "[notify_web] mosquitto_rr -h broker -W 21 -t notifier -e \"response/$$\" -m \"${msg}\""
  response=$(mosquitto_rr -h broker -W 21 -t notifier -e "response/$$" -m ${msg})
  returncode=$?
  trace_rc ${returncode}

  # The response looks like this: {"curl_code":0,"http_code":200,"body":"..."} where the body
  # is the base64(response body) but we don't need the response content here.
  trace "[notify_web] response=${response}"
  curl_code=$(echo "${response}" | jq -r ".curl_code")
  trace "[notify_web] curl_code=${curl_code}"
  http_code=$(echo "${response}" | jq -r ".http_code")
  trace "[notify_web] http_code=${http_code}"

  echo "${response}"

  if [ "${curl_code}" -eq "0" ] && [ "${returncode}" -eq "0" ]; then
    if [ "${http_code}" -lt "400" ]; then
      return 0
    else
      return ${http_code}
    fi
  else
    return ${curl_code} || ${returncode}
  fi

}

#
# call notify_telegram "text to send".  See https://core.telegram.org/bots/api#sendmessage
# ex in shell script: notify_telegram "Unit testing notify_telegram at `date -u +"%FT%H%MZ"`"
#
notify_telegram() {
  trace "Entering notify_telegram()..."

  local body=$(echo {\"text\":\"$1\"} | base64 | tr -d '\n')

  local returncode
  local response
  local http_code
  local curl_code
  local msg

  if [ "$TOR_TELEGRAM" = "true" ]; then
    msg="{\"response-topic\":\"response/$$\",\"cmd\":\"sendToTelegramGroup\",\"body\":\"${body}\",\"tor\":true}"
  else
    msg="{\"response-topic\":\"response/$$\",\"cmd\":\"sendToTelegramGroup\",\"body\":\"${body}\"}"
  fi

  # We use the pid as the response-topic, so there's no conflict in responses.
  trace "[notify_telegram] mosquitto_rr -h broker -W 21 -t notifier -e \"response/$$\" -m \"${msg}\""
  response=$(mosquitto_rr -h broker -W 21 -t notifier -e "response/$$" -m ${msg})
  returncode=$?
  trace_rc ${returncode}

  # The response looks like this: {"curl_code":0,"http_code":200,"body":"..."} where the body
  # is the base64(response body) but we don't need the response content here.
  trace "[notify_telegram] response=${response}"
  curl_code=$(echo "${response}" | jq -r ".curl_code")
  trace "[notify_telegram] curl_code=${curl_code}"
  http_code=$(echo "${response}" | jq -r ".http_code")
  trace "[notify_telegram] http_code=${http_code}"

  echo "${response}"

  if [ "${curl_code}" -eq "0" ] && [ "${returncode}" -eq "0" ]; then
    if [ "${http_code}" -lt "400" ]; then
      return 0
    else
      return ${http_code}
    fi
  else
    return ${curl_code} || ${returncode}
  fi

}