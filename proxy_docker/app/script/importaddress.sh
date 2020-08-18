#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

importaddress_rpc() {
  trace "[Entering importaddress_rpc()]"

  local address=${1}
  local data="{\"method\":\"importaddress\",\"params\":[\"${address}\",\"\",false]}"
  local result
  result=$(send_to_watcher_node ${data})
  local returncode=$?

  echo "${result}"

  return ${returncode}
}

importmulti_rpc() {
  trace "[Entering importmulti_rpc()]"

  local walletname=${1}
  local label=${2}
  local addresses=$(echo "${3}" | jq ".addresses" | tr -d '\n ')
#  trace "[importmulti_rpc] addresses=${addresses}"

  # Will look like:
  # [{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"}]

  # We want:
  # [{"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true,"label":"xpub"},{"scriptPubKey":{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},"timestamp":"now","watchonly":true,"label":"xpub"},{"scriptPubKey":{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},"timestamp":"now","watchonly":true,"label":"xpub"}]

  # {"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},
  # {"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true,"label":"xpub"},

  addresses=$(echo "${addresses}" | sed "s/\"address\"/\"scriptPubKey\":\{\"address\"/g" | sed "s/}/},\"timestamp\":\"now\",\"watchonly\":true,\"label\":${label}}/g")
#  trace "[importmulti_rpc] addresses=${addresses}"

  # Now we use that in the RPC string

  local rpcstring="{\"method\":\"importmulti\",\"params\":[${addresses},{\"rescan\":false}]}"
#  trace "[importmulti_rpc] rpcstring=${rpcstring}"

  local result
  result=$(send_to_watcher_node_wallet ${walletname} ${rpcstring})
  local returncode=$?

  echo "${result}"

  return ${returncode}
}
