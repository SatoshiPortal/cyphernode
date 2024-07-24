#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

elements_sendtomainchain() {
  trace "Entering elements_sendtomainchain()..."

  local request=${1}
  local address=$(echo "${request}" | jq -r ".address")
  trace "[elements_sendtomainchain] address=${address}"
  local amount=$(echo "${request}" | jq -r ".amount")
  trace "[elements_sendtomainchain] amount=${amount}"
  local subtractfeefromamount=$(echo "${request}" | jq -r ".subtractfeefromamount // false")
  trace "[elements_sendtomainchain] subtractfeefromamount=${subtractfeefromamount}"

  local response
  response=$(send_to_elements_spender_node "{\"method\":\"sendtomainchain\",\"params\":[\"${address}\",${amount},${subtractfeefromamount}]}")

  returncode=$?
  trace_rc ${returncode}
  trace "[elements_sendtomainchain] response=${response}"

  echo "${response}"

  return ${returncode}
}
