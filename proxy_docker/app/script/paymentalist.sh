#!/bin/sh

. ./trace.sh

send_to_paymentalist() {
  trace "Entering send_to_paymentalist()..."
  local returncode
  local result
  local errorstring
  local uri=${1}
  local data=${2}

  local host="${PAYMENTALIST_HOST:-http://paymentalist:8080}"
  local endpoint="${host}${uri}"

  trace "[send_to_paymentalist] curl -m 20 -s -H \"Content-Type: application/json\" -d \"${data}\" ${endpoint}"
  result=$(curl -m 20 -s -H "Content-Type: application/json" -d "${data}" "${endpoint}")
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq 0 ]; then
    #  service responded, let's see if we got an error message
    # jq -e will have a return code of 1 if the supplied tag is null.
    errorstring=$(echo "${result}" | jq -e ".error")
    if [ "$?" -eq "0" ]; then
      # Error tag not null, so there's an error
      trace "[send_to_paymentalist] error found in response: ${errorstring}"
      returncode=1
    else
      trace "[send_to_paymentalist] no error found in response, yayy!"
    fi
  fi

  trace "[send_to_paymentalist] result=${result}"

  # Output response to stdout before exiting with return code
  echo "${result}"

  trace_rc ${returncode}
  return ${returncode}
}

check_bolt11_mrh() {
  trace "Entering check_bolt11_mrh()..."

  local bolt11=${1}
  trace "[check_bolt11_mrh] bolt11=${bolt11}"
  local network=${2}
  trace "[check_bolt11_mrh] network=${network}"
  local result

  local data="{\"invoice\": \"${bolt11}\", \"network\": \"${network}\"}"
  trace "[check_bolt11_mrh] data=${data}"

  result=$(send_to_paymentalist "/check_bolt11_mrh" "${data}")
  returncode=$?

  echo "${result}"

  return ${returncode}
}