#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

elements_getpeginaddress() {
  trace "Entering elements_getpeginaddress()..."

  local response
  response=$(send_to_elements_spender_node "{\"method\":\"getpeginaddress\"}")

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

  local response
  local returncode

  response=$(send_to_elements_spender_node "{\"method\":\"claimpegin\",\"params\":[\"${rawtx}\",\"${proof}\",\"${claim_script}\"]}")
  returncode=$?

  trace_rc ${returncode}
  trace "[elements_claimpegin] response=${response}"

  echo "${response}"

  return ${returncode}
}