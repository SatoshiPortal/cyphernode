#!/bin/sh

. ./trace.sh

# SP_HOST is injected via proxy.env only when the SP feature is installed.
# Do NOT set a fallback default here: an empty SP_HOST is the signal used by
# the proxy handlers to detect that SP is not installed.

# Performs a request to the SP service and maps a non-2xx HTTP status to a
# nonzero return code. This is required because curl -sS returns 0 on HTTP
# 4xx/5xx, and response_to_client uses the return code (not the body) to decide
# the HTTP status it sends back to the caller. Without this mapping, an SP send
# failure would surface to callers as HTTP 200 with an error body.
# Usage: sp_request <timeout-secs> <path> [json-payload]
#   - payload present -> POST, absent -> GET
sp_request() {
  local timeout=${1}
  local path=${2}
  local payload=${3}

  local response rc http_code
  if [ -n "${payload}" ]; then
    response=$(curl -sS -m "${timeout}" -w '\n%{http_code}' -H 'content-type: application/json' \
      --data-binary "${payload}" "${SP_HOST}${path}")
  else
    response=$(curl -sS -m "${timeout}" -w '\n%{http_code}' "${SP_HOST}${path}")
  fi
  rc=$?

  # The HTTP status is the last line (appended via -w); strip it back off the body.
  http_code=$(printf '%s' "${response}" | tail -n1)
  response=$(printf '%s' "${response}" | sed '$d')
  if [ "${rc}" -eq 0 ] && [ -n "${http_code}" ] && [ "${http_code}" -ge 400 ]; then
    rc=1
  fi
  trace_rc ${rc}
  echo "${response}"
  return ${rc}
}

sp_spend() {
  trace "Entering sp_spend()..."
  local request=${1}

  local address amount wallet
  address=$(echo "${request}" | jq -r ".address // empty")
  amount=$(echo "${request}"  | jq -r ".amount // empty")
  wallet=$(echo "${request}"  | jq -r ".wallet // empty")

  # Resolve fee_rate: use the caller-supplied value or fetch it via the proxy's
  # existing fee estimation.
  local fee_rate
  fee_rate=$(echo "${request}" | jq -r ".fee_rate // empty")
  if [ -z "${fee_rate}" ]; then
    local conf_target
    conf_target=$(echo "${request}" | jq -r ".conf_target // .confTarget // 6")
    fee_rate=$(getfeerate "${conf_target}" | jq -r ".feerate")
    trace "[sp_spend] resolved fee_rate=${fee_rate} from conf_target=${conf_target}"
  fi

  # Map the Cyphernode wallet selector to a Bitcoin Core wallet name, mirroring
  # send_to_spender_node (e.g. "01" -> "spending01.dat"). An empty wallet lets
  # the SP service fall back to SPENDER_BTC_NODE_DEFAULT_WALLET.
  local wallet_name=""
  if [ -n "${wallet}" ]; then
    wallet_name="spending${wallet}.dat"
  fi

  local payload
  payload=$(jq -cn \
    --arg a  "${address}" \
    --arg m  "${amount}" \
    --argjson fr "${fee_rate}" \
    --arg w  "${wallet_name}" \
    '{address: $a, amount: $m, fee_rate: $fr}
     + (if $w != "" then {wallet: $w} else {} end)')

  sp_request 60 "/send" "${payload}"
}

validatespaddress() {
  trace "Entering validatespaddress()..."
  local request=${1}

  local address
  address=$(echo "${request}" | jq -r ".address // empty")
  local payload
  payload=$(jq -cn --arg a "${address}" '{address: $a}')

  sp_request 10 "/validatespaddress" "${payload}"
}

sp_watch() {
  trace "Entering sp_watch()..."
  local request=${1}

  # Translate proxy-style callback field names to sp_docker's internal names.
  local address
  local callback0conf
  local callback1conf
  local txid

  address=$(echo "${request}" | jq -r ".address // empty")
  callback0conf=$(echo "${request}" | jq -r ".unconfirmedCallbackURL // .callback0conf // empty")
  callback1conf=$(echo "${request}" | jq -r ".confirmedCallbackURL // .callback1conf // empty")
  txid=$(echo "${request}" | jq -r ".txid // empty")

  local payload
  payload=$(jq -cn \
    --arg a "${address}" \
    --arg c0 "${callback0conf}" \
    --arg c1 "${callback1conf}" \
    --arg t "${txid}" \
    '{address: $a}
     + (if $c0 != "" then {callback0conf: $c0} else {} end)
     + (if $c1 != "" then {callback1conf: $c1} else {} end)
     + (if $t  != "" then {txid: $t}          else {} end)')

  sp_request 10 "/sp_watch" "${payload}"
}

sp_unwatch() {
  trace "Entering sp_unwatch()..."
  local request=${1}

  # Translate proxy-style callback field names to sp_docker's internal names.
  local address
  local callback0conf
  local callback1conf

  address=$(echo "${request}" | jq -r ".address // empty")
  callback0conf=$(echo "${request}" | jq -r ".unconfirmedCallbackURL // .callback0conf // empty")
  callback1conf=$(echo "${request}" | jq -r ".confirmedCallbackURL // .callback1conf // empty")

  local payload
  payload=$(jq -cn \
    --arg a "${address}" \
    --arg c0 "${callback0conf}" \
    --arg c1 "${callback1conf}" \
    '{address: $a}
     + (if $c0 != "" then {callback0conf: $c0} else {} end)
     + (if $c1 != "" then {callback1conf: $c1} else {} end)')

  sp_request 10 "/sp_unwatch" "${payload}"
}

getactivespwatches() {
  trace "Entering getactivespwatches()..."

  sp_request 10 "/sp_watches"
}
