#!/bin/sh

. ./trace.sh

publish_response() {
  trace "Entering publish_response()..."

  local response=${1}
  local response_topic=${2}
  local returncode=${3}

  trace "[publish_response] response=${response}"
  trace "[publish_response] response_topic=${response_topic}"
  trace "[publish_response] returncode=${returncode}"

#  response=$(echo "${response}" | base64 | tr -d '\n')
  trace "[publish_response] mosquitto_pub -h broker -t \"${response_topic}\" -m \"${response}\""
  mosquitto_pub -h broker -t "${response_topic}" -m "${response}"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}
