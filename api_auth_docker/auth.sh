#!/bin/sh

#
# This is not designed to serve thousands of API key!
#
# 401 = authentication error
# 403 = authorization error
#
# header = {"alg":"HS256","typ":"JWT"}
# header64 = unpad(base64url(header)) = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
#
# payload = {"id":"001","exp":1538528077}
# payload64 = unpad(base64url(payload)) = eyJpZCI6IjAwMSIsImV4cCI6MTUzODUyODA3N30K
#
# signature = unpad(base64url(hmacsha256(header64.payload64, key)))
#
# token = header64.payload64.signature = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAwMSIsImV4cCI6MTUzODUyODA3N30K.signature
#
#
# Previous implementation of gatekeeper had a bug in the generation/validation of the JWT token:
# - The header and payload were in base64 instead of unpadded base64url
# - the signature was in HEX instead of unpadded base64url.
#
# Ref.: Appendix C of RFC 7515, "JSON Web Signature (JWS)"
#       https://www.rfc-editor.org/rfc/rfc7515.txt
#
# To stay backward-compatible, we'll validate the right way first and if the
# signature is not valid, we'll validate the old-broken way.
#

. ./trace.sh

verify_sign() {
  local returncode

  local header64=$(echo "${1}" | cut -sd '.' -f1)
  local payload64=$(echo "${1}" | cut -sd '.' -f2)
  local signature=$(echo "${1}" | cut -sd '.' -f3)

  trace "[verify_sign] header64=${header64}"
  trace "[verify_sign] payload64=${payload64}"
  trace "[verify_sign] signature=${signature}"

  local padding
  case $((${#payload64}%4)) in
    2) padding='=='
    ;;
    3) padding='='
    ;;
  esac
  # When broken-legacy used, padding is always empty because we were using base64
  # which is padded
  trace "[verify_sign] padding=${padding}"
  local payload
  local legacy
  # When broken-legacy used, this will fail if + and / found in payload because
  # it's base64 instead of base64url.
  payload=$(echo -n "${payload64}${padding}" | basenc --base64url -d)
  if [ "$?" -ne "0" ]; then
    # We got a legacy broken JWT with + and / in it
    trace "[verify_sign] We got a legacy broken JWT"
    legacy=1
  fi

  # Let's get the base64 broken legacy payload in case we have to validate it below...
  # If base64 -d fails, it means we got a correct JWT-formed payload.
  local legacypayload
  legacypayload=$(echo -n "${payload64}" | base64 -d)
  if [ "$?" -ne "0" ]; then
    # We got a fixed unpadded base64url, no need to try old-broken validation
    trace "[verify_sign] We got a fixed unpadded base64url, no need to try old-broken validation"
    legacy=0
  fi

  local exp
  if [ "${legacy}" -eq "1" ]; then
    exp=$(echo "${legacypayload}" | jq ".exp")
  else
    exp=$(echo "${payload}" | jq ".exp")
  fi
  local current=$(date +"%s")

  trace "[verify_sign] payload=${payload}"
  trace "[verify_sign] legacypayload=${legacypayload}"
  trace "[verify_sign] exp=${exp}"
  trace "[verify_sign] current=${current}"

  if [ ${exp} -gt ${current} ]; then
    trace "[verify_sign] Not expired, let's validate signature"
    local id=$(echo "${payload}" | jq -r ".id")
    trace "[verify_sign] id=${id}"

    # Check for code injection
    # id will usually be an int, but can be alphanum... nothing else
    case $id in (*[![:alnum:]]*|"")
      trace "[verify_sign] Potential code injection, exiting"
      return 1
    esac

    # It is so much faster to include the keys here instead of grep'ing the file for key.
    . ./keys.properties

    local key
    eval key='$ukey_'$id
    trace "[verify_sign] key=${key}"

    local msg="${header64}.${payload64}"
    trace "[verify_sign] msg=${msg}"

    local comp_sign
    if [ "${legacy}" -eq "1" ]; then
      comp_sign=$(echo -n "${msg}" | openssl dgst -hmac "${key}" -sha256 -r | cut -sd ' ' -f1)
    else
      comp_sign=$(echo -n "${msg}" | openssl dgst -hmac "${key}" -sha256 -r -binary | basenc --base64url | tr -d '=')
    fi
    trace "[verify_sign] comp_sign=${comp_sign}"

    if [ "${comp_sign}" != "${signature}" ] && [ -z "${legacy}" ]; then
      # Invalid sig and legacy empty, we don't know if legacy or not...
      # So we'll try legacy validation...
      trace "[verify_sign] Invalid signature, let's try legacy..."

      comp_sign=$(echo -n "${msg}" | openssl dgst -hmac "${key}" -sha256 -r | cut -sd ' ' -f1)
      trace "[verify_sign] comp_sign=${comp_sign}"
    fi

    if [ "${comp_sign}" = "${signature}" ]; then
      trace "[verify_sign] Valid signature!"

      verify_group ${id}
      returncode=$?

      if [ "${returncode}" -eq 0 ]; then
        echo -en "Status: 200 OK\r\n\r\n"
        return
      fi
      trace "[verify_sign] Invalid group!"
      return 3
    fi
    trace "[verify_sign] Invalid signature!"
    return 1
  fi

  trace "[verify_sign] Expired!"
  return 3
}

verify_group() {
  trace "[verify_group] Verifying group..."

  local id=${1}
  # REQUEST_URI should look like this: /v0/watch/2blablabla
  local context=$(echo "${REQUEST_URI#\/}" | cut -d '/' -f1)
  local action=$(echo "${REQUEST_URI#\/}" | cut -d '/' -f2)
  trace "[verify_group] context=${context} action=${action}"

  # Check for code injection
  # action can be alphanum... and _ and - but nothing else
  local actiontoinspect=$(echo "$action" | tr -d '_-')
  case $actiontoinspect in (*[![:alnum:]]*|"")
    trace "[verify_group] Potential code injection, exiting"
    return 3
  esac

  local needed_group
  local ugroups

  eval ugroups='$ugroups_'$id
  trace "[verify_group] user groups=${ugroups}"

  if [ ${context} = "s" ]; then
    # static files only accessible by a certain group
    needed_group=${action}
  elif [ ${context} = "v0" ]; then
    # actual api calls
    # It is so much faster to include the keys here instead of grep'ing the file for key.
    . ./api.properties
    eval needed_group='$action_'${action}
  fi

  trace "[verify_group] needed_group=${needed_group}"

  # If needed_group is empty, the action was not found in api.propeties.
  if [ -n "${needed_group}" ]; then
    case "${ugroups}" in
      *${needed_group}*) trace "[verify_group] Access granted"; return 0 ;;
    esac
  fi

  trace "[verify_group] Access NOT granted"
  return 3
}

returncode=0

# $HTTP_AUTHORIZATION = Bearer <token>
# Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAwMyIsImV4cCI6MTU0MjE0OTMyNH0=.b811067cf79c7009a0a38f110a6e3bf82cc4310aa6afae75b9d915b9febf13f7
# If this is not found in header, we leave
trace "[auth.sh] HTTP_AUTHORIZATION=${HTTP_AUTHORIZATION}"
# /bin/sh on debian points to dash, which does not support substring in the form ${var:offset:length}
if [ "-${HTTP_AUTHORIZATION%% *}" = "-Bearer" ]; then
  token="${HTTP_AUTHORIZATION#Bearer }"

  if [ -n "$token" ]; then
    trace "[auth.sh] Valid format for authorization header"
    verify_sign "${token}"
    returncode=$?
    trace "[auth.sh] returncode=${returncode}"
    [ "$returncode" -eq "0" ] && return
  fi
fi

if [ "${returncode}" -eq "1" ]; then
  echo -en "Status: 401 Unauthorized\r\n\r\n"
else
  echo -en "Status: 403 Forbidden\r\n\r\n"
fi

