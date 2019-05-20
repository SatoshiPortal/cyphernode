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

  while read msg; do
    trace "[main] New msg just arrived!"
    trace "[main] msg=${msg}"

    cmd=$(echo ${msg} | jq ".cmd" | tr -d '"')
    trace "[main] cmd=${cmd}"

    response_topic=$(echo ${msg} | jq '."response-topic"' | tr -d '"')
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

export TRACING=1

main
trace "[requesthandler] exiting"
exit $?
