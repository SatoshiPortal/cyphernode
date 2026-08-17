#!/bin/sh

. ./trace.sh
. ./sendtoelementsnode.sh

elements_importaddress_rpc() {
  trace "[Entering elements_importaddress_rpc()]"

  local address=${1}
  local label=${2}
  if [ -z "${label}" ]; then
    label="null"
  fi
  local data
  data=$(jq -nc --arg address "${address}" --arg label "${label}" '{method:"importaddress",params:{address:$address,label:$label,rescan:false}}')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
  # local data="{\"method\":\"importaddress\",\"params\":[\"${address}\",\"\",false]}"
  local result
  result=$(send_to_elements_watcher_node "${data}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}

elements_importmulti_rpc() {
  trace "[Entering elements_importmulti_rpc()]"

  local walletname=${1}
  local label=${2}
  local addresses
  addresses=$(echo "${3}" | jq -Mc --arg label "${label}" '[.addresses[] | {scriptPubKey:{address:.address},timestamp:"now",watchonly:true,label:$label}]')
  local returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
#  trace "[importmulti_rpc] addresses=${addresses}"

  # Will look like:
  # [{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"}]

  # We want:
  # [{"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true,"label":"xpub"},{"scriptPubKey":{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},"timestamp":"now","watchonly":true,"label":"xpub"},{"scriptPubKey":{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},"timestamp":"now","watchonly":true,"label":"xpub"}]

  # {"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},
  # {"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true,"label":"xpub"},

#  trace "[importmulti_rpc] addresses=${addresses}"

  # Now we use that in the RPC string

  local rpcstring
  rpcstring=$(jq -nc --argjson imports "${addresses}" '{method:"importmulti",params:[$imports,{rescan:false}]}')
  returncode=$?
  [ "${returncode}" -ne 0 ] && return "${returncode}"
#  trace "[importmulti_rpc] rpcstring=${rpcstring}"

  local result
  result=$(send_to_elements_watcher_node_wallet "${walletname}" "${rpcstring}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}
