#!/bin/sh

. ./trace.sh
. ./web.sh
. ./response.sh

main() {
  trace "Entering main()..."

  local msg
  local cmd
  local response
  local response_topic

  # Messages should have this form:
  # {"response-topic":"response/5541","cmd":"web","url":"2557df870b9a:1111/callback1conf","body":"eyJpZCI6IjUxIiwiYWRkc...dCI6MTUxNzYwMH0K"}
  while read msg; do
    trace "[main] New msg just arrived!"
    trace "[main] msg=${msg}"

    cmd=$(echo ${msg} | jq -r ".cmd")
    trace "[main] cmd=${cmd}"

    response_topic=$(echo ${msg} | jq -r '."response-topic"')
    trace "[main] response_topic=${response_topic}"

    case "${cmd}" in
      web)
        response=$(web "${msg}")
        publish_response "${response}" "${response_topic}" ${?}
        ;;
    esac
    trace "[main] msg processed"
  done
}

main
returncode=$?
trace "[requesthandler] exiting"
exit ${returncode}
