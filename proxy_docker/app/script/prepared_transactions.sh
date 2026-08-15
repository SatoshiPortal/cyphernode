#!/bin/sh

# Prepared-transaction gateway: build, verify and sign transactions WITHOUT
# broadcasting, so an automated caller (e.g. a treasury/rebalancing service)
# can persist the signed bytes and expected txid before any coins move, and
# recover from a crash by rebroadcasting exactly the persisted bytes.
#
# Every prepare is idempotent on (operationId, leg): replaying the same
# request returns byte-identical results and re-locks the same inputs, while
# a different request under the same key is rejected. Every prepare enforces
# maximumFeeSatoshis and re-verifies the signed outputs against the request.
# Broadcasting is a separate action (sendrawtransaction_exact) that emits the
# given bytes verbatim through an exact, operator-named wallet.

. ./trace.sh
. ./sendtobitcoinnode.sh
. ./sendtoelementsnode.sh

prepared_error() {
  jq -cn --arg message "$1" '{result:null,error:{code:-32602,message:$message},id:"1"}'
  return 1
}

prepared_validate_common() {
  printf '%s' "$1" | jq -e '
    type == "object"
    and (.operationId | type == "string" and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"))
    and (.leg | type == "string" and test("^(direct|funding|claim|prep|pegout)$"))
    and (.wallet | type == "string" and length > 0 and length <= 255 and (test("[[:cntrl:]]") | not))
    and (.maximumFeeSatoshis | type == "string" and test("^[1-9][0-9]*$") and (tonumber <= 2100000000000000))
  ' >/dev/null 2>&1
}

prepared_validate_transfer() {
  prepared_validate_common "$1" && printf '%s' "$1" | jq -e '
    (.address | type == "string" and length > 0 and length <= 200 and (test("[[:cntrl:]]") | not))
    and (.amountSatoshis | type == "string" and test("^[1-9][0-9]*$") and (tonumber <= 2100000000000000))
  ' >/dev/null 2>&1
}

prepared_cache_file() {
  local operation_id leg
  operation_id=$(printf '%s' "$1" | jq -r '.operationId') || return 1
  leg=$(printf '%s' "$1" | jq -r '.leg') || return 1
  printf '%s/prepared-transactions/%s-%s.json' "${DB_PATH}" "${operation_id}" "${leg}"
}

# Returns 0 with a response when cached, 2 on a cache miss, and 1 if an
# operation/leg key was reused for a contradictory request.
prepared_cached_response() {
  local request=$1 cache_file canonical stored
  cache_file=$(prepared_cache_file "${request}") || return 1
  [ -f "${cache_file}" ] || return 2
  canonical=$(printf '%s' "${request}" | jq -cS .) || return 1
  stored=$(jq -cS '.request' "${cache_file}") || return 1
  if [ "${canonical}" != "${stored}" ]; then
    prepared_error "operationId and leg already identify a different prepared request"
    return 1
  fi
  jq -c '{result:.result,error:null,id:"1"}' "${cache_file}"
}

prepared_save() {
  local request=$1 result=$2 cache_file cache_dir temp_file
  cache_file=$(prepared_cache_file "${request}") || return 1
  cache_dir=$(dirname "${cache_file}")
  umask 077
  mkdir -p "${cache_dir}" || return 1
  chmod 0700 "${cache_dir}" || return 1
  temp_file=$(mktemp "${cache_dir}/.prepared.XXXXXX") || return 1
  if ! jq -cn --argjson request "$(printf '%s' "${request}" | jq -cS .)" \
      --argjson result "${result}" '{request:$request,result:$result}' >"${temp_file}"; then
    rm -f "${temp_file}"
    return 1
  fi
  chmod 0600 "${temp_file}" || { rm -f "${temp_file}"; return 1; }
  mv -f "${temp_file}" "${cache_file}" || { rm -f "${temp_file}"; return 1; }
  jq -cn --argjson result "${result}" '{result:$result,error:null,id:"1"}'
}

prepared_rpc() {
  local chain=$1 wallet=$2 payload=$3
  if [ "${chain}" = bitcoin ]; then
    send_to_spender_wallet_name "${wallet}" "${payload}"
  else
    send_to_elements_spender_wallet_name "${wallet}" "${payload}"
  fi
}

prepared_btc_amount() {
  jq -nr --arg satoshis "$1" '$satoshis | tonumber / 100000000'
}

prepared_satoshis() {
  jq -nr --argjson amount "$1" '$amount * 100000000 | round | tostring'
}

prepared_lock_signed_inputs() {
  local chain=$1 wallet=$2 signed=$3 response inputs
  response=$(prepared_rpc "${chain}" "${wallet}" "$(jq -cn --arg raw "${signed}" '{method:"decoderawtransaction",params:[$raw]}')") || return 1
  inputs=$(printf '%s' "${response}" | jq -ec '[.result.vin[] | {txid,vout}] | select(length > 0)') || return 1
  response=$(prepared_rpc "${chain}" "${wallet}" "$(jq -cn --argjson inputs "${inputs}" '{method:"lockunspent",params:[false,$inputs]}')") || return 1
  [ "$(printf '%s' "${response}" | jq -r '.result')" = true ]
}

# Best-effort release of the inputs fundrawtransaction locked, used on every
# failure path after funding so a rejected prepare cannot ratchet the wallet's
# spendable balance down with permanently locked UTXOs. Never masks the
# original error: failures here are swallowed deliberately.
prepared_unlock_funded_inputs() {
  local chain=$1 wallet=$2 raw=$3 response inputs
  response=$(prepared_rpc "${chain}" "${wallet}" "$(jq -cn --arg raw "${raw}" '{method:"decoderawtransaction",params:[$raw]}')" 2>/dev/null) || return 0
  inputs=$(printf '%s' "${response}" | jq -ec '[.result.vin[] | {txid,vout}] | select(length > 0)' 2>/dev/null) || return 0
  prepared_rpc "${chain}" "${wallet}" "$(jq -cn --argjson inputs "${inputs}" '{method:"lockunspent",params:[true,$inputs]}')" >/dev/null 2>&1 || true
}

prepared_transfer() {
  local chain=$1 request=$2 cached_status wallet address amount_satoshis maximum_fee amount
  local response raw funded fee_satoshis blinded signed decoded result output_matches cache_response
  local compare_address
  if ! prepared_validate_transfer "${request}"; then
    prepared_error "invalid prepared transfer request"
    return 1
  fi
  response=$(prepared_cached_response "${request}")
  cached_status=$?
  if [ "${cached_status}" -eq 0 ]; then
    signed=$(printf '%s' "${response}" | jq -er '.result.signedHex') || return 1
    prepared_lock_signed_inputs "${chain}" "$(printf '%s' "${request}" | jq -r '.wallet')" "${signed}" || {
      prepared_error "could not re-lock cached prepared transaction inputs"; return 1;
    }
    printf '%s\n' "${response}"
    return 0
  fi
  if [ "${cached_status}" -ne 2 ]; then [ -n "${response}" ] && printf '%s\n' "${response}"; return 1; fi

  wallet=$(printf '%s' "${request}" | jq -r '.wallet')
  address=$(printf '%s' "${request}" | jq -r '.address')
  amount_satoshis=$(printf '%s' "${request}" | jq -r '.amountSatoshis')
  maximum_fee=$(printf '%s' "${request}" | jq -r '.maximumFeeSatoshis')
  amount=$(prepared_btc_amount "${amount_satoshis}") || return 1
  # Elements decodes outputs with the UNCONFIDENTIAL address form (the
  # blinding key travels separately as commitmentnonce), so verification must
  # compare against that form when the caller supplies a confidential address.
  if [ "${chain}" = elements ]; then
    response=$(prepared_rpc elements "${wallet}" "$(jq -cn --arg address "${address}" '{method:"validateaddress",params:[$address]}')") || { printf '%s\n' "${response}"; return 1; }
    compare_address=$(printf '%s' "${response}" | jq -er '.result | select(.isvalid == true) | .unconfidential // .address') || {
      prepared_error "destination is not a valid Elements address"
      return 1
    }
  else
    compare_address=${address}
  fi
  response=$(prepared_rpc "${chain}" "${wallet}" "$(jq -cn --arg address "${address}" --argjson amount "${amount}" '{method:"createrawtransaction",params:[[],{($address):$amount},0,true]}')") || { printf '%s\n' "${response}"; return 1; }
  raw=$(printf '%s' "${response}" | jq -er '.result') || return 1
  if [ "${chain}" = elements ]; then
    response=$(prepared_rpc elements "${wallet}" "$(jq -cn --arg raw "${raw}" '{method:"fundrawtransaction",params:[$raw,{lock_unspents:true,replaceable:true}]}')") || { printf '%s\n' "${response}"; return 1; }
  else
    response=$(prepared_rpc bitcoin "${wallet}" "$(jq -cn --arg raw "${raw}" '{method:"fundrawtransaction",params:[$raw,{lockUnspents:true,replaceable:true}]}')") || { printf '%s\n' "${response}"; return 1; }
  fi
  funded=$(printf '%s' "${response}" | jq -er '.result.hex') || return 1
  # fundrawtransaction has locked the selected inputs; from here on every
  # failure path must release them or repeated rejected prepares drain the
  # wallet's spendable balance.
  fee_satoshis=$(prepared_satoshis "$(printf '%s' "${response}" | jq -er '.result.fee')") || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1;
  }
  if [ "${fee_satoshis}" -gt "${maximum_fee}" ]; then
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"
    prepared_error "prepared transaction fee exceeds maximumFeeSatoshis"
    return 1
  fi
  response=$(prepared_rpc "${chain}" "${wallet}" "$(jq -cn --arg raw "${funded}" '{method:"decoderawtransaction",params:[$raw]}')") || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"
    printf '%s\n' "${response}"; return 1;
  }
  decoded=$(printf '%s' "${response}" | jq -ec '.result') || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1;
  }
  output_matches=$(printf '%s' "${decoded}" | jq -r --arg address "${compare_address}" --arg amount "${amount_satoshis}" '
    [.vout[] | select(.scriptPubKey.address == $address) | (.value * 100000000 | round | tostring)] | length == 1 and .[0] == $amount
  ') || { prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1; }
  [ "${output_matches}" = true ] || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"
    prepared_error "funded transaction output contradicts request"; return 1;
  }
  if [ "${chain}" = elements ]; then
    response=$(prepared_rpc elements "${wallet}" "$(jq -cn --arg raw "${funded}" '{method:"blindrawtransaction",params:[$raw]}')") || {
      prepared_unlock_funded_inputs elements "${wallet}" "${funded}"
      printf '%s\n' "${response}"; return 1;
    }
    blinded=$(printf '%s' "${response}" | jq -er '.result') || {
      prepared_unlock_funded_inputs elements "${wallet}" "${funded}"; return 1;
    }
  else
    blinded=${funded}
  fi
  response=$(prepared_rpc "${chain}" "${wallet}" "$(jq -cn --arg raw "${blinded}" '{method:"signrawtransactionwithwallet",params:[$raw]}')") || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"
    printf '%s\n' "${response}"; return 1;
  }
  signed=$(printf '%s' "${response}" | jq -er 'select(.result.complete == true) | .result.hex') || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1;
  }
  response=$(prepared_rpc "${chain}" "${wallet}" "$(jq -cn --arg raw "${signed}" '{method:"decoderawtransaction",params:[$raw]}')") || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"
    printf '%s\n' "${response}"; return 1;
  }
  decoded=$(printf '%s' "${response}" | jq -ec '.result') || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1;
  }
  output_matches=$(printf '%s' "${decoded}" | jq -r --arg address "${compare_address}" '[.vout[] | select(.scriptPubKey.address == $address)] | length == 1') || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1;
  }
  [ "${output_matches}" = true ] || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"
    prepared_error "prepared transaction output contradicts request"; return 1;
  }
  result=$(jq -cn --arg signedHex "${signed}" \
    --arg expectedTxid "$(printf '%s' "${decoded}" | jq -r '.txid')" \
    --arg feeSatoshis "${fee_satoshis}" --arg outputAmountSatoshis "${amount_satoshis}" \
    --arg outputAddress "${address}" \
    '{signedHex:$signedHex,expectedTxid:$expectedTxid,feeSatoshis:$feeSatoshis,outputAmountSatoshis:$outputAmountSatoshis,outputAddress:$outputAddress}') || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1;
  }
  cache_response=$(prepared_save "${request}" "${result}") || {
    prepared_unlock_funded_inputs "${chain}" "${wallet}" "${funded}"; return 1;
  }
  prepared_lock_signed_inputs "${chain}" "${wallet}" "${signed}" || {
    prepared_error "could not lock prepared transaction inputs"; return 1;
  }
  printf '%s\n' "${cache_response}"
}

prepared_pegin_claim() {
  local request=$1 cached_status response wallet maximum_fee expected signed decoded fee_satoshis output result
  if ! prepared_validate_common "${request}" || ! printf '%s' "${request}" | jq -e '
      .leg == "claim"
      and (.bitcoinTransaction | type == "string" and test("^([0-9a-fA-F]{2})+$"))
      and (.txOutProof | type == "string" and test("^([0-9a-fA-F]{2})+$"))
      and (.claimScript | type == "string" and test("^([0-9a-fA-F]{2})+$"))
      and (.expectedAmountSatoshis | type == "string" and test("^[1-9][0-9]*$"))
    ' >/dev/null 2>&1; then
    prepared_error "invalid prepared peg-in claim request"; return 1
  fi
  response=$(prepared_cached_response "${request}"); cached_status=$?
  if [ "${cached_status}" -eq 0 ]; then printf '%s\n' "${response}"; return 0; fi
  if [ "${cached_status}" -ne 2 ]; then [ -n "${response}" ] && printf '%s\n' "${response}"; return 1; fi
  wallet=$(printf '%s' "${request}" | jq -r '.wallet')
  maximum_fee=$(printf '%s' "${request}" | jq -r '.maximumFeeSatoshis')
  expected=$(printf '%s' "${request}" | jq -r '.expectedAmountSatoshis')
  response=$(prepared_rpc elements "${wallet}" "$(printf '%s' "${request}" | jq -c '{method:"createrawpegin",params:[.bitcoinTransaction,.txOutProof,.claimScript]}')") || { printf '%s\n' "${response}"; return 1; }
  signed=$(printf '%s' "${response}" | jq -er '.result.hex') || return 1
  response=$(prepared_rpc elements "${wallet}" "$(jq -cn --arg raw "${signed}" '{method:"signrawtransactionwithwallet",params:[$raw]}')") || { printf '%s\n' "${response}"; return 1; }
  signed=$(printf '%s' "${response}" | jq -er 'select(.result.complete == true) | .result.hex') || return 1
  response=$(prepared_rpc elements "${wallet}" "$(jq -cn --arg raw "${signed}" '{method:"decoderawtransaction",params:[$raw]}')") || { printf '%s\n' "${response}"; return 1; }
  decoded=$(printf '%s' "${response}" | jq -ec '.result') || return 1
  fee_satoshis=$(printf '%s' "${decoded}" | jq -r '[.vout[] | select(.scriptPubKey.type == "fee") | .value * 100000000 | round] | add | tostring') || return 1
  output=$(printf '%s' "${decoded}" | jq -ec '[.vout[] | select(.scriptPubKey.address != null and .scriptPubKey.type != "fee") | {address:.scriptPubKey.address,amount:(.value * 100000000 | round | tostring)}] | if length == 1 then .[0] else error("ambiguous peg-in output") end') || return 1
  [ "${fee_satoshis}" -le "${maximum_fee}" ] || { prepared_error "prepared peg-in fee exceeds maximumFeeSatoshis"; return 1; }
  [ "$(printf '%s' "${output}" | jq -r '.amount')" -ge "${expected}" ] || { prepared_error "prepared peg-in output is below expectedAmountSatoshis"; return 1; }
  result=$(jq -cn --arg signedHex "${signed}" --arg expectedTxid "$(printf '%s' "${decoded}" | jq -r '.txid')" \
    --arg feeSatoshis "${fee_satoshis}" --arg outputAmountSatoshis "$(printf '%s' "${output}" | jq -r '.amount')" \
    --arg outputAddress "$(printf '%s' "${output}" | jq -r '.address')" \
    '{signedHex:$signedHex,expectedTxid:$expectedTxid,feeSatoshis:$feeSatoshis,outputAmountSatoshis:$outputAmountSatoshis,outputAddress:$outputAddress}') || return 1
  prepared_save "${request}" "${result}"
}

prepared_broadcast() {
  local chain=$1 request=$2 response txid wallet payload
  if ! printf '%s' "${request}" | jq -e '
      type == "object" and (.hex | type == "string" and test("^([0-9a-fA-F]{2})+$"))
      and (.wallet == null or (.wallet | type == "string" and length > 0 and length <= 255 and (test("[[:cntrl:]]") | not)))
    ' >/dev/null 2>&1; then prepared_error "invalid raw transaction"; return 1; fi
  wallet=$(printf '%s' "${request}" | jq -r '.wallet // empty')
  payload=$(printf '%s' "${request}" | jq -c '{method:"sendrawtransaction",params:[.hex]}')
  if [ "${chain}" = bitcoin ]; then
    if [ -n "${wallet}" ]; then response=$(send_to_spender_wallet_name "${wallet}" "${payload}"); else response=$(send_to_spender_node "${payload}"); fi
  else
    if [ -n "${wallet}" ]; then response=$(send_to_elements_spender_wallet_name "${wallet}" "${payload}"); else response=$(send_to_elements_spender_node "${payload}"); fi
  fi
  [ "$?" -eq 0 ] || { printf '%s\n' "${response}"; return 1; }
  txid=$(printf '%s' "${response}" | jq -er '.result') || return 1
  jq -cn --arg txid "${txid}" '{result:{txid:$txid},error:null,id:"1"}'
}
