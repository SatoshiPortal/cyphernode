#!/bin/sh

. ./trace.sh

ln_create_invoice()
{
  trace "Entering ln_create_invoice()..."

  local result
  local data
  local id

  local request=${1}
  local msatoshi=$(echo "${request}" | jq ".msatoshi" | tr -d '"')
  trace "[ln_create_invoice] msatoshi=${msatoshi}"
  local label=$(echo "${request}" | jq ".label" | tr -d '"')
  trace "[ln_create_invoice] label=${label}"
  local description=$(echo "${request}" | jq ".description" | tr -d '"')
  trace "[ln_create_invoice] description=${description}"
  local expiry=$(echo "${request}" | jq ".expiry" | tr -d '"')
  trace "[ln_create_invoice] expiry=${expiry}"
  local callback_url=$(echo "${request}" | jq ".callbackUrl" | tr -d '"')
  trace "[ln_create_invoice] callback_url=${callback_url}"

  #/proxy $ ./lightning-cli invoice 10000 "t1" "t1d" 60
  #{
  #  "payment_hash": "a74e6cccb06e26bcddc32c43674f9c3cf6b018a4cb9e9ff7f835cc59b091ae06",
  #  "expires_at": 1546648644,
  #  "bolt11": "lnbc100n1pwzllqgpp55a8xen9sdcntehwr93pkwnuu8nmtqx9yew0flalcxhx9nvy34crqdq9wsckgxqzpucqp2rzjqt04ll5ft3mcuy8hws4xcku2pnhma9r9mavtjtadawyrw5kgzp7g7zr745qq3mcqqyqqqqlgqqqqqzsqpcr85k33shzaxscpj29fadmjmfej6y2p380x9w4kxydqpxq87l6lshy69fry9q2yrtu037nt44x77uhzkdyn8043n5yj8tqgluvmcl69cquaxr68"
  #}

  trace "[ln_create_invoice] ./lightning-cli invoice ${msatoshi} \"${label}\" \"${description}\" ${expiry}"
  result=$(./lightning-cli invoice ${msatoshi} "${label}" "${description}" ${expiry})
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_create_invoice] result=${result}"

  if [ "${returncode}" -ne "0" ]; then
    data=${result}
  else
    local bolt11=$(echo "${result}" | jq ".bolt11" | tr -d '"')
    trace "[ln_create_invoice] bolt11=${bolt11}"
    local payment_hash=$(echo "${result}" | jq ".payment_hash" | tr -d '"')
    trace "[ln_create_invoice] payment_hash=${payment_hash}"
    local expires_at=$(echo "${result}" | jq ".expires_at" | tr -d '"')
    trace "[ln_create_invoice] expires_at=${expires_at}"

    # Let's get the connect string if provided in configuration
    local connectstring=$(get_connection_string)

    sql "INSERT OR IGNORE INTO ln_invoice (label, bolt11, callback_url, payment_hash, expires_at, msatoshi, description, status) VALUES (\"${label}\", \"${bolt11}\", \"${callback_url}\", \"${payment_hash}\", ${expires_at}, ${msatoshi}, \"${description}\", \"unpaid\")"
    trace_rc $?
    id=$(sql "SELECT id FROM ln_invoice WHERE bolt11=\"${bolt11}\"")
    trace_rc $?

    data="{\"id\":\"${id}\","
    data="${data}\"label\":\"${label}\","
    data="${data}\"bolt11\":\"${bolt11}\","
    if [ -n "${connectstring}" ]; then
      data="${data}\"connectstring\":\"${connectstring}\","
    fi
    data="${data}\"callback_url\":\"${callback_url}\","
    data="${data}\"payment_hash\":\"${payment_hash}\","
    data="${data}\"msatoshi\":${msatoshi},"
    data="${data}\"status\":\"unpaid\","
    data="${data}\"description\":\"${description}\","
    data="${data}\"expires_at\":${expires_at}}"
    trace "[ln_create_invoice] data=${data}"
  fi

  echo "${data}"

  return ${returncode}
}

ln_get_connection_string() {
  trace "Entering ln_get_connection_string()..."

  echo "{\"connectstring\":\"$(get_connection_string)\"}"
}

get_connection_string() {
  trace "Entering get_connection_string()..."

  # Let's get the connect string if provided in configuration
  local connectstring
  local getinfo=$(ln_getinfo)
  echo ${getinfo} | jq -e '.address[0]' > /dev/null
  if [ "$?" -eq 0 ]; then
    # If there's an address
    connectstring="$(echo ${getinfo} | jq '((.id + "@") + (.address[0] | ((.address + ":") + (.port | tostring))))' | tr -d '"')"
    trace "[get_connection_string] connectstring=${connectstring}"
  fi

  echo "${connectstring}"
}

ln_getinfo()
{
  trace "Entering ln_get_info()..."

  local result

  result=$(./lightning-cli getinfo)
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_getinfo] result=${result}"

  echo "${result}"

  return ${returncode}
}

ln_getinvoice() {
  trace "Entering ln_getinvoice()..."

  local label=${1}
  local result

  result=$(./lightning-cli listinvoices ${label})
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_getinvoice] result=${result}"

  echo "${result}"

  return ${returncode}
}

ln_delinvoice() {
  trace "Entering ln_delinvoice()..."

  local label=${1}
  local result
  local returncode
  local rc

  trace "[ln_delinvoice] ./lightning-cli delinvoice ${label} \"unpaid\""
  result=$(./lightning-cli delinvoice ${label} "unpaid")
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_delinvoice] result=${result}"

  if [ "${returncode}" -ne "0" ]; then
    # Special case of error: if status is expired, we're ok
    echo "${result}" | grep "not unpaid" > /dev/null
    rc=$?
    trace_rc ${rc}

    if [ "${rc}" -eq "0" ]; then
      trace "Invoice is paid or expired, it's ok"
      # String found
      returncode=0
    fi
  fi

  echo "${result}"

  return ${returncode}
}

ln_decodebolt11() {
  trace "Entering ln_decodebolt11()..."

  local bolt11=${1}
  local result

  result=$(./lightning-cli decodepay ${bolt11})
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_decodebolt11] result=${result}"

  echo "${result}"

  return ${returncode}
}

ln_connectfund() {
  trace "Entering ln_connectfund()..."

  local result
  local returncode
  local tx
  local txid
  local nodeId

  local request=${1}
  local peer=$(echo "${request}" | jq ".peer" | tr -d '"')
  trace "[ln_connectfund] peer=${peer}"
  local msatoshi=$(echo "${request}" | jq ".msatoshi")
  trace "[ln_connectfund] msatoshi=${msatoshi}"
  local callback_url=$(echo "${request}" | jq ".callbackUrl" | tr -d '"')
  trace "[ln_connectfund] callback_url=${callback_url}"

  # Let's first try to connect to peer
  trace "[ln_connectfund] ./lightning-cli connect ${peer}"
  result=$(./lightning-cli connect ${peer})
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_connectfund] result=${result}"

  if [ "${returncode}" -eq "0" ]; then
    # Connected

# ./lightning-cli connect 038863cf8ab91046230f561cd5b386cbff8309fa02e3f0c3ed161a3aeb64a643b9@180.181.208.42:9735
# {
#  "id": "038863cf8ab91046230f561cd5b386cbff8309fa02e3f0c3ed161a3aeb64a643b9"
# }

# ./lightning-cli connect 021a1b197aa79242532b23cb9a8d9cb78631f95f811457675fa1b362fe6d1c24b8@172.81.180.244:9735
# { "code" : -1, "message" : "172.1.180.244:9735: Connection establishment: Operation timed out. " }

    nodeId=$(echo "${result}" | jq ".id" | tr -d '"')
    trace "[ln_connectfund] nodeId=${nodeId}"

    # Now let's fund a channel with peer
    trace "[ln_connectfund] ./lightning-cli fundchannel ${nodeId} ${msatoshi}"
    result=$(./lightning-cli fundchannel ${nodeId} ${msatoshi})
    returncode=$?
    trace_rc ${returncode}
    trace "[ln_connectfund] result=${result}"

    if [ "${returncode}" -eq "0" ]; then
      # funding succeeded

# ./lightning-cli fundchannel 038863cf8ab91046230f561cd5b386cbff8309fa02e3f0c3ed161a3aeb64a643b9 1000000
# {
#  "tx": "020000000001011594f707cf2ec076278072bc64f893bbd70188db42ea49e9ba531ee3c7bc8ed00100000000ffffffff0240420f00000000002200206149ff97921356191dc1f2e9ab997c459a71e8050d272721abf4b4d8a92d2419a6538900000000001600142cab0184d0f8098f75ebe05172b5864395e033f402483045022100b25cd5a9d49b5cc946f72a58ccc0afe652d99c25fba98d68be035a286f55849802203de5b504c44f775a0101b6025f116b73bf571e776e4efcac0475721bfde4d08a0121038360308a394158b0799196c5179a6480a75db73207fb93d4a673d934c9f786f400000000", 
#  "txid": "747bf7d1c40bebed578b3f02a3d8da9a56885851a3c4bdb6e1b8de19223559a4", 
#  "channel_id": "a459352219deb8e1b6bdc4a3515888569adad8a3023f8b57edeb0bc4d1f77b74"
# }

# ./lightning-cli fundchannel 038863cf8ab91046230f561cd5b386cbff8309fa02e3f0c3ed161a3aeb64a643b9 100000
# { "code" : 301, "message" : "Cannot afford transaction" }

      # Let's find what to watch
      txid=$(echo "${result}" | jq ".txid" | tr -d '"')
      tx=$(echo "${result}" | jq ".tx" | tr -d '"')

      
    else
      # Error funding
      trace "[ln_connectfund] Error funding, result=${result}"
    fi
  else
    # Error connecting
    trace "[ln_connectfund] Error connecting, result=${result}"
  fi

}

ln_pay() {
  trace "Entering ln_pay()..."

  # We'll use pay that will manage the routing and waitsendpay to make sure a payment succeeded or failed.
  # 1. pay
  # 2. waitsendpay IF pay returned a status of "pending" (code 200)

  local result
  local returncode
  local code
  local status
  local payment_hash

  local request=${1}
  local bolt11=$(echo "${request}" | jq ".bolt11" | tr -d '"')
  trace "[ln_pay] bolt11=${bolt11}"
  local expected_msatoshi=$(echo "${request}" | jq ".expected_msatoshi")
  trace "[ln_pay] expected_msatoshi=${expected_msatoshi}"
  local expected_description=$(echo "${request}" | jq ".expected_description")
  trace "[ln_pay] expected_description=${expected_description}"

  # Let's first decode the bolt11 string to make sure we are paying the good invoice
  trace "[ln_pay] ./lightning-cli decodepay ${bolt11}"
  result=$(./lightning-cli decodepay ${bolt11})
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_pay] result=${result}"

  if [ "${returncode}" -eq "0" ]; then
    local invoice_msatoshi=$(echo "${result}" | jq ".msatoshi")
    trace "[ln_pay] invoice_msatoshi=${invoice_msatoshi}"
    local invoice_description=$(echo "${result}" | jq ".description")
    trace "[ln_pay] invoice_description=${invoice_description}"

    # The amount must match
    if [ "${expected_msatoshi}" != "${invoice_msatoshi}" ]; then
      result="{\"result\":\"error\",\"expected_msatoshi\":${expected_msatoshi},\"invoice_msatoshi\":${invoice_msatoshi}}"
      returncode=1
    elif [ "${expected_description}" != '""' ] && [ "${expected_description}" != "${invoice_description}" ]; then
      # If expected description is empty, we accept any description on the invoice.  Amount is the important thing.

      result="{\"result\":\"error\",\"expected_description\":${expected_description},\"invoice_description\":${invoice_description}}"
      returncode=1
    else
      # Amount and description is as expected, let's pay!
      trace "[ln_pay] Amount and description are as expected, let's try to pay!"

      trace "[ln_pay] ./lightning-cli pay -k bolt11=${bolt11} retry_for=15"
      result=$(./lightning-cli pay -k bolt11=${bolt11} retry_for=15)
      returncode=$?
      trace_rc ${returncode}
      trace "[ln_pay] result=${result}"

      # The result should contain a status field with value pending, complete or failed.
      # If complete, we can return with success.
      # If failed, we can return with failed.
      # If pending, we should keep trying until complete or failed status, before responding to client.
      # We'll use waitsendpay for that.

      if [ "${returncode}" -ne "0" ]; then
        trace "[ln_pay] payment not complete, let's see what's going on."

        code=$(echo "${result}" | jq -e ".code")
        # jq -e will have a return code of 1 if the supplied tag is null.
        if [ "$?" -eq "0" ]; then
          # code tag not null, so there's an error
          trace "[ln_pay] Error code found, code=${code}"

          if [ "${code}" -eq "200" ]; then
            trace "[ln_pay] Code 200, let's fetch status in data, should be pending..."
            status=$(echo "${result}" | jq ".data.status" | tr -d '"')
            trace "[ln_pay] status=${status}"
          else
            trace "[ln_pay] Failure code, response will be the cli result."
          fi
        else
          # code tag not found
          trace "[ln_pay] No error code, getting the status..."
          status=$(echo "${result}" | jq ".status" | tr -d '"')
          trace "[ln_pay] status=${status}"
        fi

        if [ "${status}" = "pending" ]; then
          trace "[ln_pay] Ok let's deal with pending status with waitsendpay."

          payment_hash=$(echo "${result}" | jq ".data.payment_hash" | tr -d '"')
          trace "[ln_pay] ./lightning-cli waitsendpay ${payment_hash} 15"
          result=$(./lightning-cli waitsendpay ${payment_hash} 15)
          returncode=$?
          trace_rc ${returncode}
          trace "[ln_pay] result=${result}"

          if [ "${returncode}" -ne "0" ]; then
            trace "[ln_pay] Failed!"
          else
            trace "[ln_pay] Successfully paid!"
          fi
        fi
      else
        trace "[ln_pay] Successfully paid!"
      fi
    fi
  fi

# Example of error result:
#
# { "code" : 204, "message" : "failed: WIRE_TEMPORARY_CHANNEL_FAILURE (Outgoing subdaemon died)", "data" :
# {
#   "erring_index": 0,
#   "failcode": 4103,
#   "erring_node": "031b867d9d6631a1352cc0f37bcea94bd5587a8d4f40416c4ce1a12511b1e68f56",
#   "erring_channel": "1452982:62:0"
# } }
#
#
# Example of successful result:
#
# {
#   "id": 44,
#   "payment_hash": "de648062da7117903291dab2075881e49ddd78efbf82438e4a2f486a7ebe0f3a",
#   "destination": "02be93d1dad1ccae7beea7b42f8dbcfbdafb4d342335c603125ef518200290b450",
#   "msatoshi": 207000,
#   "msatoshi_sent": 207747,
#   "created_at": 1548380406,
#   "status": "complete",
#   "payment_preimage": "a7ef27e9a94d63e4028f35ca4213fd9008227ad86815cd40d3413287d819b145",
#   "description": "Order 43012 - Satoshi Larrivee",
#   "getroute_tries": 1,
#   "sendpay_tries": 1,
#   "route": [
#     {
#       "id": "02be93d1dad1ccae7beea7b42f8dbcfbdafb4d342335c603125ef518200290b450",
#       "channel": "1452749:174:0",
#       "msatoshi": 207747,
#       "delay": 10
#     }
#   ],
#   "failures": [
#   ]
# }

  echo "${result}"

  return ${returncode}
}

ln_newaddr()
{
  trace "Entering ln_newaddr()..."

  local result

  result=$(./lightning-cli newaddr)
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_newaddr] result=${result}"

  echo "${result}"

  return ${returncode}
}

case "${0}" in *call_lightningd.sh) ./lightning-cli $@;; esac
