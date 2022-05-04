#!/bin/sh

. ./trace.sh
. ./web.sh
. ./response.sh
. ./sql.sh


main() {
  trace "Entering main()..."

  while true; do
    loadConfig

    readLoop
  done

}

readLoop(){
  local msg
  local cmd
  local response
  local response_topic
  local url

  trace "[readLoop] Starting"

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
      sendToTelegramGroup)
        # example:
        #   local body=$(echo "{\"text\":\"Hello world in Telegram at `date -u +"%FT%H%MZ"`\"}" | base64)
        #   response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"sendToTelegramGroup\",\"body\":\"${body}\"}")
        if [ "${FEATURE_TELEGRAM}" = "true" ]; then
          url=$(echo ${TG_BOT_URL}${TG_API_KEY}/sendMessage?chat_id=${TG_CHAT_ID})
          trace "[main] telegram-url=${url}"

          msg=$(echo ${msg} | jq --arg url ${url} '. += {"url":$url}' )
          trace "[main] web-msg=${msg}"

          response=$(web "${msg}")
          publish_response "${response}" "${response_topic}" ${?}
        else
          trace "[main] Telegram is NOT enabled - message not sent"
        fi
        ;;
      sendToTelegramNoop)
        if [ "${FEATURE_TELEGRAM}" = "true" ]; then
          url=$(echo ${TG_BOT_URL}${TG_API_KEY}/getMe)
          trace "[main] telegram-url=${url}"

          msg=$(echo ${msg} | jq --arg url ${url} '. += {"url":$url}' )
          trace "[main] web-msg=${msg}"

          response=$(web "${msg}")
          publish_response "${response}" "${response_topic}" ${?}
        else
          trace "[main] Telegram is NOT enabled - message not sent"
        fi
        ;;
     reloadConfig)
        trace "[main] Reloading configs Now"
        response="{\"return_code\":\"(loadConfig)\"}"
        trace "[main] response=${response}"
        publish_response "${response}" "${response_topic}" ${?}
        trace "[main] Reloading configs - Done"

        # restart read loop
        break
        ;;
    esac
    trace "[main] msg processed"
  done
}

loadConfig(){
  if [ "${FEATURE_TELEGRAM}" = "true" ]; then
    trace "[loadConfig] FEATURE_TELEGRAM is ENABLED"

    # wait for table to exist in DB - for clean install
    waitfortable "cyphernode_props" 

    trace "[loadConfig] Looking up TG_BOT_URL in database"

    TG_BOT_URL=$(sql "SELECT value FROM cyphernode_props WHERE category='notifier' AND property='tg_base_url'")
    returncode=$?
    trace "[loadConfig] TG_BOT_URL [${TG_BOT_URL}]"
    trace_rc ${returncode}

    [ "${returncode}" -ne "0" ] && return 10

    trace "[loadConfig] Looking up TG_API_KEY in database"
    TG_API_KEY=$(sql "SELECT value FROM cyphernode_props WHERE category='notifier' AND property='tg_api_key'")
    returncode=$?
    trace "[loadConfig] TG_API_KEY [${TG_API_KEY}]"
    trace_rc ${returncode}
    [ "${returncode}" -ne "0" ] && return 20

    trace "[loadConfig] Looking up TG_CHAT_ID in database"
    TG_CHAT_ID=$(sql "SELECT value FROM cyphernode_props WHERE category='notifier' AND property='tg_chat_id'")
    returncode=$?
    trace "[loadConfig] TG_CHAT_ID [${TG_CHAT_ID}]"
    trace_rc ${returncode}
    [ "${returncode}" -ne "0" ] && return 30
  else
    trace "[loadConfig] FEATURE_TELEGRAM is DISABLED"
  fi

  echo "0"
}

main
returncode=$?
trace "[requesthandler] exiting"
exit ${returncode}
