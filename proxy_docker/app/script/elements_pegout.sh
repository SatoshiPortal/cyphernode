#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

elements_sendtomainchain() {
  trace "Entering elements_sendtomainchain()..."

  local request=${1}
  local wallet=$(echo "${request}" | jq -r ".wallet // empty")
  trace "[elements_sendtomainchain] wallet=${wallet}"
  local address=$(echo "${request}" | jq -r ".address")
  trace "[elements_sendtomainchain] address=${address}"
  local amount=$(echo "${request}" | jq -r ".amount")
  trace "[elements_sendtomainchain] amount=${amount}"
  local subtractfeefromamount=$(echo "${request}" | jq -r ".subtractfeefromamount // false")
  trace "[elements_sendtomainchain] subtractfeefromamount=${subtractfeefromamount}"

  local response
  local data="{\"method\":\"sendtomainchain\",\"params\":[\"${address}\",${amount},${subtractfeefromamount}]}"

  if [ -n "${wallet}" ]; then
    response=$(send_to_elements_spender_node "${data}" "${wallet}")
  else
    response=$(send_to_elements_spender_node "${data}")
  fi

  returncode=$?
  trace_rc ${returncode}
  trace "[elements_sendtomainchain] response=${response}"

  echo "${response}"

  return ${returncode}
}
