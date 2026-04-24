#!/bin/sh

. ./trace.sh

# SP_HOST is injected via proxy.env only when the SP feature is installed.
# Do NOT set a fallback default here: an empty SP_HOST is the signal used by
# the proxy handlers to detect that SP is not installed.

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

  local payload
  payload=$(jq -cn \
    --arg a  "${address}" \
    --arg m  "${amount}" \
    --argjson fr "${fee_rate}" \
    --arg w  "${wallet}" \
    '{address: $a, amount: $m, fee_rate: $fr}
     + (if $w != "" then {wallet: $w} else {} end)')

  local response
  response=$(curl -sS -m 60 -H 'content-type: application/json' \
    --data-binary "${payload}" "${SP_HOST}/send")
  local rc=$?
  trace_rc ${rc}
  echo "${response}"
  return ${rc}
}

validatespaddress() {
  trace "Entering validatespaddress()..."
  local request=${1}

  local address
  address=$(echo "${request}" | jq -r ".address // empty")
  local payload
  payload=$(jq -cn --arg a "${address}" '{address: $a}')

  local response
  response=$(curl -sS -m 10 -H 'content-type: application/json' \
    --data-binary "${payload}" "${SP_HOST}/validatespaddress")
  local rc=$?
  trace_rc ${rc}
  echo "${response}"
  return ${rc}
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

  local response
  response=$(curl -sS -m 10 -H 'content-type: application/json' \
    --data-binary "${payload}" "${SP_HOST}/sp_watch")
  local rc=$?
  trace_rc ${rc}
  echo "${response}"
  return ${rc}
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

  local response
  response=$(curl -sS -m 10 -H 'content-type: application/json' \
    --data-binary "${payload}" "${SP_HOST}/sp_unwatch")
  local rc=$?
  trace_rc ${rc}
  echo "${response}"
  return ${rc}
}

getactivespwatches() {
  trace "Entering getactivespwatches()..."

  local response
  response=$(curl -sS -m 10 "${SP_HOST}/sp_watches")
  local rc=$?
  trace_rc ${rc}
  echo "${response}"
  return ${rc}
}
