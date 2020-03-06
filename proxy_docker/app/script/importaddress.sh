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
  local rescan=${4}

  # always false unless true
  if [ "$rescan" != "true" ]; then
      rescan="false"
  fi

#  trace "[importmulti_rpc] addresses=${addresses}"

  # Will look like:
  # [{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"}]

  # We want:
  # [{"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true,"label":"xpub"},{"scriptPubKey":{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},"timestamp":"now","watchonly":true,"label":"xpub"},{"scriptPubKey":{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},"timestamp":"now","watchonly":true,"label":"xpub"}]

  # {"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},
  # {"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true,"label":"xpub"},

  addresses=$(echo "${addresses}" | sed "s/\"address\"/\"scriptPubKey\":\{\"address\"/g" | sed "s/}/},\"timestamp\":\"now\",\"watchonly\":true,\"label\":\"${label}\"}/g")
#  trace "[importmulti_rpc] addresses=${addresses}"

  # Now we use that in the RPC string

  local rpcstring="{\"method\":\"importmulti\",\"params\":[${addresses},{\"rescan\":${rescan}}]}"
#  trace "[importmulti_rpc] rpcstring=${rpcstring}"

  local result
  result=$(send_to_watcher_node_wallet ${walletname} ${rpcstring})
  local returncode=$?

  echo "${result}"

  return ${returncode}
}


importmulti_descriptor_rpc() {

  # can be called multiple times for the same ranges and descriptors
  trace "[Entering importmulti_descriptor_rpc()]"

  local walletname=${1}
  local label=${2}
  local descriptor=${3}
  local rStart=${4:-0}
  local rEnd=${5:-$XPUB_DERIVATION_GAP}
  local keypool=${6:-true}
  local internal=${7:-false}

  trace "[importmulti_descriptor_rpc] walletname=${walletname}"
  trace "[importmulti_descriptor_rpc] label=${label}"
  trace "[importmulti_descriptor_rpc] descriptor=${descriptor}"
  trace "[importmulti_descriptor_rpc] rStart=${rStart}"
  trace "[importmulti_descriptor_rpc] rEnd=${rEnd}"
  trace "[importmulti_descriptor_rpc] internal=${internal}"
  trace "[importmulti_descriptor_rpc] keypool=${keypool}"

  # always false unless true
  if [ "$rescan" != "true" ]; then
      rescan="false"
  fi

  local toimport
  if [ "$internal" != "true" ]; then
    toimport="[{\"desc\":\"${descriptor}\",\"timestamp\":\"now\",\"range\":[${rStart},${rEnd}],\"watchonly\":true,\"label\":\"${label}\",\"keypool\":${keypool},\"internal\":false}]"
  else
    toimport="[{\"desc\":\"${descriptor}\",\"timestamp\":\"now\",\"range\":[${rStart},${rEnd}],\"watchonly\":true,\"keypool\":${keypool},\"internal\":true}]"
  fi

  if [ "$keypool" != "false" ]; then
    rescan="true"
  fi

  trace "[importmulti_descriptor_rpc] toimport=${toimport}"

  local rpcstring="{\"method\":\"importmulti\",\"params\":[${toimport},{\"rescan\":false}]}"

  echo "RPCSTR=${rpcstring}"

  local result
  result=$(send_to_psbt_wallet "${rpcstring}")
  local returncode=$?

  echo "${result}"

  return ${returncode}
}

