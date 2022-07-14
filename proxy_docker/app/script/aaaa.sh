#!/bin/sh
#
#
#
#

#. ./responsetoclient.sh
. ./trace.sh

TRACING=1
mkdir -p /cnlogs

response_to_client()
{
  trace "Entering response_to_client()..."

  local response=${1}
  local returncode=${2}
  local contenttype=${3}
  trace "[response_to_client] response=$response"
  trace "[response_to_client] returncode=$returncode"
  trace "[response_to_client] contenttype=$contenttype"
  local length=$(echo -n "${response}" | wc -c)
  trace "[response_to_client] length=$length"

  [ -z "${contenttype}" ] && contenttype="application/json"
  trace "[response_to_client] contenttype=$contenttype"

  ([ -z "${returncode}" ] || [ "${returncode}" -eq "0" ]) && trace "r1" && echo -n "HTTP/1.1 200 OK\r\n"
  [ -n "${returncode}" ] && [ "${returncode}" -ne "0" ] && trace "r2" && echo -n "HTTP/1.1 400 Bad Request\r\n"
  trace "[response_to_client] after http code"

  echo -n "Content-Type: ${contenttype}\r\nContent-Length: ${length}\r\n\r\n${response}"
  trace "[response_to_client] after headers and response"

  # Small delay needed for the data to be processed correctly by peer
  sleep 1
}

main() {
  trace "Entering main()..."

  local step=0
  local cmd
  local http_method
  local line
  local content_length
  local response
  local returncode

  while read line; do
    line=$(echo "${line}" | tr -d '\r\n')
    trace "[main] line=${line}"

    if [ "${cmd}" = "" ]; then
      # First line!
      # Looking for something like:
      # GET /cmd/params HTTP/1.1
      # POST / HTTP/1.1
      cmd=$(echo "${line}" | cut -d '/' -f2 | cut -d ' ' -f1)
      trace "[main] cmd=${cmd}"
      http_method=$(echo "${line}" | cut -d ' ' -f1)
      trace "[main] http_method=${http_method}"
      if [ "${http_method}" = "GET" ]; then
        step=1
      fi
    fi
    if [ "${line}" = "" ]; then
      trace "[main] empty line"
      if [ ${step} -eq 1 ]; then
        trace "[main] body part finished, disconnecting"
        break
      else
        trace "[main] headers part finished, body incoming"
        step=1
      fi
    fi
    # line=content-length: 406
    case "${line}" in
      *[cC][oO][nN][tT][eE][nN][tT]-[lL][eE][nN][gG][tT][hH]*)
        content_length=$(echo "${line}" | cut -d ' ' -f2)
        trace "[main] content_length=${content_length}";
      ;;
    esac
    if [ ${step} -eq 1 ]; then
      trace "[main] step=${step}"
      if [ "${http_method}" = "POST" ] && [ "${content_length}" -gt "0" ]; then
      # read -rd '' -n ${content_length} line
        echo "cl=$content_length" >&2
      # stty raw
        line=$(dd bs=1 count=${content_length} 2>/dev/null)
      # stty -raw
        echo "line=$line" >&2
        line=$(echo "${line}" | jq -c)
        trace "[main] line=${line}"
      fi
      case "${cmd}" in
        helloworld)
          # GET http://192.168.111.152:8080/helloworld
          response='{"hello":"world"}'
          returncode=0
          # response_to_client "Hello, world!" 0
          # break
          ;;
        *)
          response='{"error": {"code": -32601, "message": "Method not found"}, "id": "1"}'
          returncode=1
          ;;
      esac
      response=$(echo "${response}" | jq -Mc)
      response_to_client "${response}" ${returncode}
      break
    fi
  done
  trace "[main] exiting"
  return ${returncode}
}

main
returncode=$?
trace "[requesthandler] exiting"
exit ${returncode}
