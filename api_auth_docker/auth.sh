#!/bin/sh

#
# This is not designed to serve thousands of API key!
#
# header = {"alg":"HS256","typ":"JWT"}
# header64 = base64(header) = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9Cg==
#
# payload = {"id":"001","exp":1538528077}
# payload64 = base64(payload) = eyJpZCI6IjAwMSIsImV4cCI6MTUzODUyODA3N30K
#
# signature = hmacsha256(header64.payload64, key)
#
# token = header64.payload64.signature = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9Cg==.eyJpZCI6IjAwMSIsImV4cCI6MTUzODUyODA3N30K.signature
#

. ./trace.sh

verify()
{
  local header64=$(echo ${1} | cut -sd '.' -f1)
  local payload64=$(echo ${1} | cut -sd '.' -f2)
  local signature=$(echo ${1} | cut -sd '.' -f3)

  trace "[verify] header64=${header64}"
  trace "[verify] payload64=${payload64}"
  trace "[verify] signature=${signature}"

  local payload=$(echo ${payload64} | base64 -d)
  local exp=$(echo ${payload} | jq ".exp")
  local current=$(date +"%s")

  trace "[verify] payload=${payload}"
  trace "[verify] exp=${exp}"
  trace "[verify] current=${current}"

  if [ ${exp} -gt ${current} ]; then
  trace "[verify] Not expired, let's validate signature"
  local id=$(echo ${payload} | jq ".id" | tr -d '"')
  trace "[verify] id=${id}"

  # It is so much faster to include the keys here instead of grep'ing the file for key.
  . ./keys.properties

  local key
  eval key='$key'$id
  trace "[verify] key=${key}"
    local comp_sign=$(echo "${header64}.${payload64}" | openssl dgst -hmac "${key}" -sha256 -r | cut -sd ' ' -f1)

    trace "[verify] comp_sign=${comp_sign}"

  if [ "${comp_sign}" = "${signature}" ]; then
  trace "[verify] Valid signature!"
  echo -en "Status: 200 OK\r\n\r\n"
  return
  fi
  trace "[verify] Invalid signature!"
  return 1
  fi

  trace "[verify] Expired!"

  return 1
}

# $HTTP_AUTHORIZATION = Bearer <token>
trace "[auth.sh] HTTP_AUTHORIZATION=${HTTP_AUTHORIZATION}"
if [ "${HTTP_AUTHORIZATION:0:6}" = "Bearer" ]; then
  token="${HTTP_AUTHORIZATION:6}"

  if [ -n "$token" ]; then
  trace "[auth.sh] Valid format for authorization header"
  verify "${token}"
  [ "$?" -eq "0" ] && return
  fi
fi

echo -en "Status: 403 Forbidden\r\n\r\n"
