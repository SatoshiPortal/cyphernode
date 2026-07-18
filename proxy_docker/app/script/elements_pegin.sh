#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

elements_getpeginaddress() {
  trace "Entering elements_getpeginaddress()..."

  local wallet=${1:-}

  local response
  local data="{\"method\":\"getpeginaddress\"}"
  if [ -n "${wallet}" ]; then
    response=$(send_to_elements_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_elements_spender_node "${data}")
  fi

  returncode=$?
  trace_rc ${returncode}
  trace "[elements_getpeginaddress] response=${response}"

  echo "${response}"

  return ${returncode}
}

elements_claimpegin() {
  trace "Entering elements_claimpegin()..."

  local request=${1}
  local rawtx=$(echo "${request}" | jq -r ".rawtx")
  trace "[elements_claimpegin] rawtx=${rawtx}"
  local proof=$(echo "${request}" | jq -r ".proof")
  trace "[elements_claimpegin] proof=${proof}"
  local claim_script=$(echo "${request}" | jq -r ".claim_script")
  trace "[elements_claimpegin] claim_script=${claim_script}"
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  if [ -n "${wallet}" ]; then
    trace "[elements_claimpegin] wallet=${wallet}"
  fi

  local response
  local returncode
  local data
  data=$(jq -nc --arg rawtx "${rawtx}" --arg proof "${proof}" --arg claim_script "${claim_script}" \
    '{method:"claimpegin",params:[$rawtx,$proof,$claim_script]}')
  returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  if [ -n "${wallet}" ]; then
    response=$(send_to_elements_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_elements_spender_node "${data}")
  fi
  returncode=$?

  trace_rc ${returncode}
  trace "[elements_claimpegin] response=${response}"

  echo "${response}"

  return ${returncode}
}
