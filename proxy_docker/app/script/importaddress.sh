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
  local addresses=$(echo "${2}" | jq ".addresses" | tr -d '\n ')
  trace "[importmulti_rpc] addresses=${addresses}"

# [{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]
# [{"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true},{"scriptPubKey":{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},"timestamp":"now","watchonly":true},{"scriptPubKey":{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},"timestamp":"now","watchonly":true}]

# {"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},
# {"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true},

  addresses=$(echo "${addresses}" | sed "s/\"address\"/\"scriptPubKey\":\{\"address\"/g" | sed "s/}/},\"timestamp\":\"now\",\"watchonly\":true,\"label\":\"${walletname}\"}/g")
  trace "[importmulti_rpc] addresses=${addresses}"

#  {"method":"importmulti","params":["requests":[<req>],"options":{"rescan":false}]}
#  <req> = {"address":"<addr>","timestamp":"now","watchonly":true},...

  local rpcstring="{\"method\":\"importmulti\",\"params\":[${addresses},{\"rescan\":false}]}"
  trace "[importmulti_rpc] rpcstring=${rpcstring}"

  local result
#  result=$(send_to_watcher_node_wallet ${walletname} ${rpcstring})
  result=$(send_to_watcher_node ${rpcstring})
  local returncode=$?

  echo "${result}"

  return ${returncode}
}


#[{"requests":
#  [
#    {"scriptPubKey":{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},"timestamp":"now","watchonly":true},
#    {"scriptPubKey":{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},"timestamp":"now","watchonly":true},
#    {"scriptPubKey":{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},"timestamp":"now","watchonly":true}
#  ]},
#{"options":
#  {
#    "rescan":false
#  }
#}]








#
# /usr/bin $ ./bitcoin-cli help importmulti
# importmulti "requests" ( "options" )
#
# Import addresses/scripts (with private or public keys, redeem script (P2SH)), rescanning all addresses in one-shot-only (rescan can be disabled via options). Requires a new wallet backup.
#
# Arguments:
# 1. requests     (array, required) Data to be imported
#   [     (array of json objects)
#     {
#       "scriptPubKey": "<script>" | { "address":"<address>" }, (string / json, required) Type of scriptPubKey (string for script, json for address)
#       "timestamp": timestamp | "now"                        , (integer / string, required) Creation time of the key in seconds since epoch (Jan 1 1970 GMT),
#                                                               or the string "now" to substitute the current synced blockchain time. The timestamp of the oldest
#                                                               key will determine how far back blockchain rescans need to begin for missing wallet transactions.
#                                                               "now" can be specified to bypass scanning, for keys which are known to never have been used, and
#                                                               0 can be specified to scan the entire blockchain. Blocks up to 2 hours before the earliest key
#                                                               creation time of all keys being imported by the importmulti call will be scanned.
#       "redeemscript": "<script>"                            , (string, optional) Allowed only if the scriptPubKey is a P2SH address or a P2SH scriptPubKey
#       "pubkeys": ["<pubKey>", ... ]                         , (array, optional) Array of strings giving pubkeys that must occur in the output or redeemscript
#       "keys": ["<key>", ... ]                               , (array, optional) Array of strings giving private keys whose corresponding public keys must occur in the output or redeemscript
#       "internal": <true>                                    , (boolean, optional, default: false) Stating whether matching outputs should be treated as not incoming payments
#       "watchonly": <true>                                   , (boolean, optional, default: false) Stating whether matching outputs should be considered watched even when they're not spendable, only allowed if keys are empty
#       "label": <label>                                      , (string, optional, default: '') Label to assign to the address (aka account name, for now), only allowed with internal=false
#     }
#   ,...
#   ]
# 2. options                 (json, optional)
#   {
#      "rescan": <false>,         (boolean, optional, default: true) Stating if should rescan the blockchain after all imports
#   }
#
# Note: This call can take over an hour to complete if rescan is true, during that time, other rpc calls
# may report that the imported keys, addresses or scripts exists but related transactions are still missing.
#
# Examples:
# > bitcoin-cli importmulti '[{ "scriptPubKey": { "address": "<my address>" }, "timestamp":1455191478 }, { "scriptPubKey": { "address": "<my 2nd address>" }, "label": "example 2", "timestamp": 1455191480 }]'
# > bitcoin-cli importmulti '[{ "scriptPubKey": { "address": "<my address>" }, "timestamp":1455191478 }]' '{ "rescan": false}'
#
# Response is an array with the same size as the input that has the execution result :
#   [{ "success": true } , { "success": false, "error": { "code": -1, "message": "Internal Server Error"} }, ... ]
#
