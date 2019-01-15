#!/bin/sh

. ./trace.sh

response_to_client()
{
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

htmlfile_response_to_client()
{
  trace "Entering htmlfile_response_to_client()..."

  local path=${1}
  local filename=${2}
  local pathfile="${path}${filename}"
  local returncode

  trace "[htmlfile_response_to_client] path=${path}"
  trace "[htmlfile_response_to_client] filename=${filename}"
  trace "[htmlfile_response_to_client] pathfile=${pathfile}"
  local file_length=$(stat -c'%s' ${pathfile})
  trace "[htmlfile_response_to_client] file_length=${file_length}"

  [ -r "${pathfile}" ] \
  && echo -ne "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ${file_length}\r\n\r\n" \
  && cat ${pathfile}

  [ ! -r "${pathfile}" ] && echo -ne "HTTP/1.1 404 Not Found\r\n"

  # Small delay needed for the data to be processed correctly by peer
  sleep 1
}

binfile_response_to_client()
{
  trace "Entering binfile_response_to_client()..."

  local path=${1}
  local filename=${2}
  local pathfile="${path}${filename}"
  local returncode

  trace "[file_response_to_client] path=${path}"
  trace "[file_response_to_client] filename=${filename}"
  trace "[file_response_to_client] pathfile=${pathfile}"
  local file_length=$(stat -c'%s' ${pathfile})
  trace "[file_response_to_client] file_length=${file_length}"

  [ -r "${pathfile}" ] \
  && echo -ne "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: inline; filename=\"${filename}\"\r\nContent-Length: ${file_length}\r\n\r\n" \
  && cat ${pathfile}

  [ ! -r "${pathfile}" ] && echo -ne "HTTP/1.1 404 Not Found\r\n"

  # Small delay needed for the data to be processed correctly by peer
  sleep 1
}

case "${0}" in *responsetoclient.sh) response_to_client $@;; esac
