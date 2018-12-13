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

GRAFANA_PREFIX=gatekeeper

. ./trace.sh
. ./monitoring.sh

verify_sign()
{

  monitoring_count "verify_sign.call" 1 $GRAFANA_PREFIX

  local returncode

  local header64=$(echo ${1} | cut -sd '.' -f1)
  local payload64=$(echo ${1} | cut -sd '.' -f2)
  local signature=$(echo ${1} | cut -sd '.' -f3)

  trace "[verify_sign] header64=${header64}"
  trace "[verify_sign] payload64=${payload64}"
  trace "[verify_sign] signature=${signature}"

  local payload=$(echo -n ${payload64} | base64 -d)
  local exp=$(echo ${payload} | jq ".exp")
  local current=$(date +"%s")

  trace "[verify_sign] payload=${payload}"
  trace "[verify_sign] exp=${exp}"
  trace "[verify_sign] current=${current}"

  if [ ${exp} -gt ${current} ]; then
    trace "[verify_sign] Not expired, let's validate signature"
    local id=$(echo ${payload} | jq ".id" | tr -d '"')
    trace "[verify_sign] id=${id}"

    # Check for code injection
    # id will usually be an int, but can be alphanum... nothing else
    case $id in (*[![:alnum:]]*|"")
      monitoring_count "error.verify_sign.codeinjection" 1 $GRAFANA_PREFIX
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

    local comp_sign=$(echo -n "${msg}" | openssl dgst -hmac "${key}" -sha256 -r | cut -sd ' ' -f1)
    trace "[verify_sign] comp_sign=${comp_sign}"

    if [ "${comp_sign}" = "${signature}" ]; then
      monitoring_count "verify_sign.validsig" 1 $GRAFANA_PREFIX
      trace "[verify_sign] Valid signature!"

      verify_group ${id}
      returncode=$?

      if [ "${returncode}" -eq 0 ]; then
        monitoring_count "verify_sign.granted" 1 $GRAFANA_PREFIX
        echo -en "Status: 200 OK\r\n\r\n"
        return
      fi
      monitoring_count "error.verify_sign.invalidgroup" 1 $GRAFANA_PREFIX
      trace "[verify_sign] Invalid group!"
      return 1
    fi
    monitoring_count "error.verify_sign.invalidsig" 1 $GRAFANA_PREFIX
    trace "[verify_sign] Invalid signature!"
    return 1
  fi

  monitoring_count "error.verify_sign.expired" 1 $GRAFANA_PREFIX
  trace "[verify_sign] Expired!"
  return 1
}

verify_group()
{

  monitoring_count "verify_group.call" 1 $GRAFANA_PREFIX
  trace "[verify_group] Verifying group..."

  local id=${1}
  # REQUEST_URI should look like this: /v0/watch/2blablabla
  local action=$(echo "${REQUEST_URI#\/}" | cut -d '/' -f2)
  trace "[verify_group] action=${action}"

  # Check for code injection
  # action can be alphanum... and _ and - but nothing else
	local actiontoinspect=$(echo "$action" | tr -d '_-')
  case $actiontoinspect in (*[![:alnum:]]*|"")
    monitoring_count "error.verify_group.codeinjection" 1 $GRAFANA_PREFIX
    trace "[verify_group] Potential code injection, exiting"
    return 1
  esac

  # It is so much faster to include the keys here instead of grep'ing the file for key.
  . ./api.properties

  local needed_group
  local ugroups

  eval needed_group='$action_'${action}
  trace "[verify_group] needed_group=${needed_group}"

  eval ugroups='$ugroups_'$id
  trace "[verify_group] user groups=${ugroups}"

  case "${ugroups}" in
    *${needed_group}*)
      monitoring_count "verify_group.granted" 1 $GRAFANA_PREFIX
      trace "[verify_group] Access granted"
      return 0
      ;;
  esac

  monitoring_count "error.verify_group.denied" 1 $GRAFANA_PREFIX
  trace "[verify_group] Access NOT granted"
  return 1
}


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
    [ "$?" -eq "0" ] && return
  fi
fi

monitoring_count "error.main.forbidden" 1 $GRAFANA_PREFIX
echo -en "Status: 403 Forbidden\r\n\r\n"
