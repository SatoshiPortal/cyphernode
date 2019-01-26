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

      trace "[ln_pay] ./lightning-cli pay ${bolt11}"
      result=$(./lightning-cli pay ${bolt11})
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
          trace "[ln_pay] ./lightning-cli waitsendpay ${payment_hash}"
          result=$(./lightning-cli waitsendpay ${payment_hash})
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
