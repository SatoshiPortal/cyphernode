#!/bin/sh

. ./trace.sh

response_to_client() {
  trace "Entering response_to_client()..."

  local response=${1}
  local returncode=${2}
  local contenttype=${3}
  local length=$(echo -en "${response}" | wc -c)

  [ -z "${contenttype}" ] && contenttype="application/json"

  ([ -z "${returncode}" ] || [ "${returncode}" -eq "0" ]) && echo -ne "HTTP/1.1 200 OK\r\n"
  [ -n "${returncode}" ] && [ "${returncode}" -ne "0" ] && echo -ne "HTTP/1.1 400 Bad Request\r\n"

  echo -en "Content-Type: ${contenttype}\r\nContent-Length: ${length}\r\n\r\n${response}"

  # Small delay needed for the data to be processed correctly by peer
  sleep 1
}

case "${0}" in *responsetoclient.sh) response_to_client $@;; esac
