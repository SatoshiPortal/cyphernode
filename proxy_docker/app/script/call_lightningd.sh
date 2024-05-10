#!/bin/sh

. ./trace.sh

ln_call_lightningd() {
  trace "Entering ln_call_lightningd()..."

  local response
  local returncode

  trace "[ln_call_lightningd] ./lightning-cli $(printf " \"%s\"" "$@")"
  response=$(./lightning-cli "$@")
  returncode=$?
  trace_rc ${returncode}

  echo "${response}"

  return ${returncode}
}

ln_create_invoice() {
  trace "Entering ln_create_invoice()..."

  local result
  local data
  local id

  local request=${1}

  local cln_args

  local msatoshi=$(echo "${request}" | jq -r ".msatoshi")
  trace "[ln_create_invoice] msatoshi=${msatoshi}"
  if [ "${msatoshi}" = "null" ]; then
    cln_args='msatoshi="any"'
  else
    cln_args="msatoshi=${msatoshi}"
  fi
  local label=$(echo "${request}" | jq -r ".label")
  trace "[ln_create_invoice] label=${label}"
  local esclabel=$(echo "${request}" | jq ".label")
  trace "[ln_create_invoice] esclabel=${esclabel}"
  local description=$(echo "${request}" | jq -r ".description")
  trace "[ln_create_invoice] description=${description}"
  local escdescription=$(echo "${request}" | jq ".description")
  trace "[ln_create_invoice] escdescription=${escdescription}"
  local expiry=$(echo "${request}" | jq -r ".expiry")
  trace "[ln_create_invoice] expiry=${expiry}"
  if [ "${expiry}" != "null" ]; then
    cln_args="${cln_args} expiry=${expiry}"
  fi
  local callback_url=$(echo "${request}" | jq -r ".callbackUrl")
  trace "[ln_create_invoice] callback_url=${callback_url}"
  pgcallback_url=${callback_url}
  if [ "${callback_url}" != "null" ]; then
    # If not null, let's add double-quotes so we don't need to add the double-quotes in the sql insert,
    # so if it's null, it will insert the actual sql NULL value.
    pgcallback_url="'${callback_url}'"
  fi
  trace "[ln_create_invoice] pgcallback_url=${pgcallback_url}"
  local deschashonly=$(echo "${request}" | jq -r ".deschashonly")
  trace "[ln_create_invoice] deschashonly=${deschashonly}"
  if [ "${deschashonly}" = "true" ]; then
    trace "[ln_create_invoice] using description hash"
    cln_args="${cln_args} deschashonly=true"
  fi

  trace "[ln_create_invoice] ./lightning-cli -k invoice 'label=${esclabel}' 'description=${escdescription}' ${cln_args}"
  result=$(ln_call_lightningd -k invoice label="${esclabel}" description="${escdescription}" ${cln_args})

  returncode=$?
  trace_rc ${returncode}
  trace "[ln_create_invoice] result=${result}"

  if [ "${returncode}" -ne "0" ]; then
    data=${result}
  else
    local bolt11=$(echo "${result}" | jq -r ".bolt11")
    trace "[ln_create_invoice] bolt11=${bolt11}"
    local payment_hash=$(echo "${result}" | jq -r ".payment_hash")
    trace "[ln_create_invoice] payment_hash=${payment_hash}"
    local expires_at=$(echo "${result}" | jq -r ".expires_at")
    trace "[ln_create_invoice] expires_at=${expires_at}"

    # Let's get the connect string if provided in configuration
    local connectstring=$(get_connection_string)

    id=$(sql "INSERT INTO ln_invoice (label, bolt11, callback_url, payment_hash, expires_at, msatoshi, description, status)"\
" VALUES ('${label}','${bolt11}', ${pgcallback_url},'${payment_hash}', ${expires_at}, ${msatoshi}, '${description}', 'unpaid')"\
" RETURNING id" \
    "SELECT id FROM ln_invoice WHERE bolt11='${bolt11}'")
    trace_rc $?

    data="{\"id\":${id},"
    data="${data}\"label\":${esclabel},"
    data="${data}\"bolt11\":\"${bolt11}\","
    if [ -n "${connectstring}" ]; then
      data="${data}\"connectstring\":\"${connectstring}\","
    fi
    if [ "${callback_url}" != "null" ]; then
      data="${data}\"callbackUrl\":\"${callback_url}\","
    fi
    data="${data}\"payment_hash\":\"${payment_hash}\","
    if [ "${msatoshi}" != "null" ]; then
      data="${data}\"msatoshi\":${msatoshi},"
      data="${data}\"amount_msat\":${msatoshi},"
    fi
    data="${data}\"status\":\"unpaid\","
    data="${data}\"description\":${escdescription},"
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
    connectstring="$(echo ${getinfo} | jq -r '((.id + "@") + (.address[0] | ((.address + ":") + (.port | tostring))))')"
    trace "[get_connection_string] connectstring=${connectstring}"
  fi

  echo "${connectstring}"
}

ln_getinfo() {
  trace "Entering ln_get_info()..."

  local result

  result=$(ln_call_lightningd getinfo)
  returncode=$?

  echo "${result}"

  return ${returncode}
}

ln_getinvoice() {
  trace "Entering ln_getinvoice()..."

  local label=${1}
  trace "[ln_getinvoice] label=${label}"
  local result

  result=$(ln_call_lightningd listinvoices "${label}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}

ln_delinvoice() {
  trace "Entering ln_delinvoice()..."

  local label=${1}
  local result
  local returncode
  local rc

  result=$(ln_call_lightningd delinvoice "${label}" "unpaid")
  returncode=$?

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

  result=$(ln_call_lightningd decodepay "${bolt11}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}

ln_connectfund() {
  trace "Entering ln_connectfund()..."

  # {"peer":"nodeId@ip:port","msatoshi":"100000","callbackUrl":"https://callbackUrl/?channelReady=f3y2c3cvm4uzg2gq"}

  local result
  local returncode
  local tx
  local txid
  local nodeId
  local data
  local channel_id
  local msg

  local request=${1}
  local peer=$(echo "${request}" | jq -r ".peer")
  trace "[ln_connectfund] peer=${peer}"
  local msatoshi=$(echo "${request}" | jq ".msatoshi")
  trace "[ln_connectfund] msatoshi=${msatoshi}"
  local callback_url=$(echo "${request}" | jq -r ".callbackUrl")
  trace "[ln_connectfund] callback_url=${callback_url}"

  # Let's first try to connect to peer
  result=$(ln_call_lightningd connect "${peer}")
  returncode=$?

  if [ "${returncode}" -eq "0" ]; then
    # Connected

# ./lightning-cli connect 038863cf8ab91046230f561cd5b386cbff8309fa02e3f0c3ed161a3aeb64a643b9@180.181.208.42:9735
# {
#  "id": "038863cf8ab91046230f561cd5b386cbff8309fa02e3f0c3ed161a3aeb64a643b9"
# }

# ./lightning-cli connect 021a1b197aa79242532b23cb9a8d9cb78631f95f811457675fa1b362fe6d1c24b8@172.81.180.244:9735
# { "code" : -1, "message" : "172.1.180.244:9735: Connection establishment: Operation timed out. " }

    nodeId=$(echo "${result}" | jq -r ".id")
    trace "[ln_connectfund] nodeId=${nodeId}"

    # Now let's fund a channel with peer
    result=$(ln_call_lightningd fundchannel "${nodeId}" "$((${msatoshi}/1000))")
    returncode=$?

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
      txid=$(echo "${result}" | jq ".txid")
      tx=$(echo "${result}" | jq ".tx")
      channel_id=$(echo "${result}" | jq ".channel_id")

      data="{\"txid\":${txid},\"xconfCallbackURL\":\"${callback_url}\",\"nbxconf\":6}"

      result=$(watchtxidrequest "${data}")
      returncode=$?
      trace_rc ${returncode}
      trace "[ln_connectfund] result=${result}"

      if [ "${returncode}" -eq "0" ]; then
        result="{\"result\":\"success\",\"txid\":${txid},\"channel_id\":${channel_id}}"
      else
        trace "[ln_connectfund] Error watching txid, result=${result}"
        result="{\"result\":\"failed\",\"message\":\"Failed at watching txid\"}"
      fi
    else
      # Error funding
      trace "[ln_connectfund] Error funding, result=${result}"
      msg=$(echo "${result}" | jq ".message")
      result="{\"result\":\"failed\",\"message\":${msg}}"
    fi
  else
    # Error connecting
    trace "[ln_connectfund] Error connecting, result=${result}"
    msg=$(echo "${result}" | jq ".message")
    result="{\"result\":\"failed\",\"message\":${msg}}"
  fi

  echo "${result}"

  return ${returncode}
}

ln_pay() {
  trace "Entering ln_pay()..."

  # Let's try to pay (MPP enabled) for 85 seconds.
  # If this doesn't work for a routing reason, let's try to legacypay (MPP disabled) for 85 seconds.
  # If this doesn't work, return an error.

  local result
  local returncode
  local code
  local status
  local payment_hash

  local request=${1}
  local bolt11=$(echo "${request}" | jq -r ".bolt11")
  trace "[ln_pay] bolt11=${bolt11}"
  local expected_msatoshi=$(echo "${request}" | jq ".expected_msatoshi")
  trace "[ln_pay] expected_msatoshi=${expected_msatoshi}"
  if [ "${expected_msatoshi}" = "null" ]; then
    expected_msatoshi=$(echo "${request}" | jq ".expectedMsatoshi")
    trace "[ln_pay] expected_msatoshi=${expected_msatoshi}"
  fi
  local expected_description=$(echo "${request}" | jq -r ".expected_description")
  trace "[ln_pay] expected_description=${expected_description}"
  if [ "${expected_description}" = "null" ]; then
    expected_description=$(echo "${request}" | jq -r ".expectedDescription")
    trace "[ln_pay] expected_description=${expected_description}"
  fi

  # Let's first decode the bolt11 string to make sure we are paying the good invoice
  result=$(ln_call_lightningd decodepay "${bolt11}")
  returncode=$?

  if [ "${returncode}" -eq "0" ]; then
    local invoice_msatoshi=$(echo "${result}" | jq ".amount_msat")
    trace "[ln_pay] invoice_msatoshi=${invoice_msatoshi}"
    local invoice_description=$(echo "${result}" | jq ".description")
    trace "[ln_pay] invoice_description=${invoice_description}"

    # The amount must match if not "any"
    # If the amount is not in the invoice and not supplied as expected_msatoshi, then both will be null, that's ok!
    # Same thing goes for the description.
    if [ -n "${expected_msatoshi}" ] && [ "${expected_msatoshi}" != "null" ]  &&  [ "${expected_msatoshi}" != "${invoice_msatoshi}" ] && [ "${invoice_msatoshi}" != "null" ]; then
      # If invoice_msatoshi is null, that means "any" was supplied, so the amounts don't have to match!
      result="{\"result\":\"error\",\"expected_msatoshi\":${expected_msatoshi},\"invoice_msatoshi\":${invoice_msatoshi}}"
      trace "[ln_pay] Expected msatoshi <> Invoice msatoshi"
      returncode=1
    elif [ -n "${expected_description}" ] && [ "${expected_description}" != "null" ] && [ "${expected_description}" != "${invoice_description}" ]; then
      # If expected description is not empty but doesn't correspond to invoice_description, there'a problem.
      # (we don't care about the description if expected description is empty.  Amount is the most important thing)

      result="{\"result\":\"error\",\"expected_description\":\"${expected_description}\",\"invoice_description\":${invoice_description}}"
      trace "[ln_pay] Expected description <> Invoice description"
      returncode=1
    else
      # Amount and description are as expected (or empty description), let's see if already paid
      trace "[ln_pay] Amount and description are as expected, let's see if already paid"
      result=$(ln_listpays "${bolt11}")
      returncode=$?
      trace_rc ${returncode}
      trace "[ln_pay] result=${result}"
      local complete pending failed
      complete=$(echo "${result}" | jq -er '.pays | map(select(.status == "complete")) | last')
      trace "[ln_pay] complete=${complete}"
      pending=$(echo "${result}" | jq -er '.pays | map(select(.status == "pending")) | last')
      trace "[ln_pay] pending=${pending}"
      failed=$(echo "${result}" | jq -er '.pays | map(select(.status == "failed")) | last')
      trace "[ln_pay] failed=${failed}"

      if [ "${complete}" != "null" ]; then
        trace "[ln_pay] responding complete"
        echo "${complete}"
        return 0
      fi
      if [ "${pending}" != "null" ]; then
        trace "[ln_pay] responding pending"
        echo "${pending}"
        return 1
      fi

      # Payment not previously done, let's pay!
      trace "[ln_pay] Payment not previously done, let's try to pay with MPP!"

      if [ "${invoice_msatoshi}" = "null" ]; then
        # "any" amount on the invoice, we force paying the expected_msatoshi provided to ln_pay by the user
        result=$(ln_call_lightningd pay -k bolt11=${bolt11} amount_msat=${expected_msatoshi} retry_for=85)
      else
        result=$(ln_call_lightningd pay -k bolt11=${bolt11} retry_for=85)
      fi
      returncode=$?
      trace_rc ${returncode}
      trace "[ln_pay] result=${result}"

      # Successful payment example:
      #
      # {
      #    "destination": "029b26c73b2c19ec9bdddeeec97c313670c96b6414ceacae0fb1b3502e490a6cbb",
      #    "payment_hash": "0d1e62210e7af9a4146258652fd4cfecd2638086850583e994a103884e2b4e78",
      #    "created_at": 1631200188.550,
      #    "parts": 1,
      #    "msatoshi": 530114,
      #    "amount_msat": "530114msat",
      #    "msatoshi_sent": 530114,
      #    "amount_sent_msat": "530114msat",
      #    "payment_preimage": "2672c5fa280367222bf30db82566b78909927a67d5756d5ae0227b2ff8f3a907",
      #    "status": "complete"
      # }
      #
      #
      # Failed payment example:
      # {
      #    "code": 210,
      #    "message": "Destination 029b26c73b2c19ec9bdddeeec97c313670c96b6414ceacae0fb1b3502e490a6cbb is not reachable directly and all routehints were unusable.",
      #    "attempts": [
      #       {
      #          "status": "failed",
      #          "failreason": "Destination 029b26c73b2c19ec9bdddeeec97c313670c96b6414ceacae0fb1b3502e490a6cbb is not reachable directly and all routehints were unusable.",
      #          "partid": 0,
      #          "amount": "528214msat"
      #       }
      #    ]
      # }
      #

      if [ "${returncode}" -ne "0" ]; then
        trace "[ln_pay] payment not complete, let's see what's going on."

        code=$(echo "${result}" | jq -e ".code")
        # jq -e will have a return code of 1 if the supplied tag is null.
        if [ "$?" -eq "0" ]; then
          # code tag not null, so there's an error
          trace "[ln_pay] Error code found, code=${code}"
        else
          # code tag not found
          trace "[ln_pay] No error code..."
        fi
      fi
    fi
  fi

  echo "${result}"

  return ${returncode}
}

ln_listpays() {
  trace "Entering ln_listpays()..."

  local result
  local bolt11=${1}
  trace "[ln_listpays] bolt11=${bolt11}"

  result=$(ln_call_lightningd listpays "${bolt11}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}

ln_paystatus() {
  trace "Entering ln_paystatus()..."

  local result
  local bolt11=${1}
  trace "[ln_paystatus] bolt11=${bolt11}"

  result=$(ln_call_lightningd paystatus "${bolt11}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}

ln_newaddr() {
  trace "Entering ln_newaddr()..."

  local result

  result=$(ln_call_lightningd newaddr)
  returncode=$?

  echo "${result}"

  return ${returncode}
}

ln_listpeers() {
  trace "Entering ln_listpeers()..."

  local id=${1}
  local result

  result=$(ln_call_lightningd listpeers "${id}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}
ln_listfunds() {
  trace "Entering ln_listfunds()..."

  local result

  result=$(ln_call_lightningd listfunds)
  returncode=$?

  echo "${result}"

  return ${returncode}
}
ln_getroute() {
  trace "Entering ln_getroute()..."
  # Defaults used from c-lightning documentation

  local result
  local id=${1}
  local msatoshi=${2}
  local riskfactor=${3}

  result=$(ln_call_lightningd getroute -k id="${id}" amount_msat=${msatoshi} riskfactor=${riskfactor})
  returncode=$?

  echo "${result}"

  return ${returncode}
}

ln_withdraw() {
  trace "Entering ln_withdraw()..."
  # Defaults used from c-lightning documentation

  local result
  local request=${1}
  local destination=$(echo "${request}" | jq -r ".destination")
  local satoshi=$(echo "${request}" | jq -r ".satoshi")
  local feerate=$(echo "${request}" | jq -r ".feerate")
  local all=$(echo "${request}" | jq -r ".all")
  if [ "${all}" = true ] || [ "${all}" = "true" ] ; then
      satoshi="all"
  fi

  result=$(ln_call_lightningd withdraw "${destination}" ${satoshi} ${feerate})
  returncode=$?

  echo "${result}"

  return ${returncode}
}

case "${0}" in *call_lightningd.sh) ln_call_lightningd "$@";; esac
