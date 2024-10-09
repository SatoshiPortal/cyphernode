#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh
. ./sql.sh
. ./blockchainrpc.sh

compute_fees() {
  local pruned=${WATCHER_BTC_NODE_PRUNED}
  if [ "${pruned}" = "true" ]; then
    trace "[compute_fees]  pruned=${pruned}"
    # We want null instead of 0.00000000 in this case.
    echo "null"
    return
  fi

  local txid=${1}

  # Let's reuse the file created in confirmation...
  local tx_raw_details=$(cat rawtx-${txid}-$$.blob)
  trace "[compute_fees]  tx_raw_details=${tx_raw_details}"
  local vin_total_amount=$(compute_vin_total_amount "${tx_raw_details}")

  local vout_total_amount=0
  local vout_value
  local vout_values=$(echo "${tx_raw_details}" | jq ".vout[].value")
  for vout_value in ${vout_values}
  do
    vout_total_amount=$(awk "BEGIN { printf(\"%.8f\", ${vout_total_amount}+${vout_value}); exit }")
  done

  trace "[compute_fees]  vin total amount=${vin_total_amount}"
  trace "[compute_fees] vout total amount=${vout_total_amount}"

  local fees=$(awk "BEGIN { printf(\"%.8f\", ${vin_total_amount}-${vout_total_amount}); exit }")
  trace "[compute_fees] fees=${fees}"

  echo "${fees}"
}

compute_vin_total_amount() {
  trace "Entering compute_vin_total_amount()..."

  local main_tx=${1}
  local vin_txids_vout=$(echo "${main_tx}" | jq '.vin[] | ((.txid + "-") + (.vout | tostring))')
  trace "[compute_vin_total_amount] vin_txids_vout=${vin_txids_vout}"
  local returncode
  local vin_txid_vout
  local vin_txid
  local vin_raw_tx
  local vin_vout_amount=0
  local vout
  local vin_total_amount=0

  for vin_txid_vout in ${vin_txids_vout}
  do
    vin_txid=$(echo "${vin_txid_vout}" | tr -d '"' | cut -d '-' -f1)
    vin_raw_tx=$(get_rawtransaction "${vin_txid}" | tr -d '\n')
    returncode=$?
    if [ "${returncode}" -ne 0 ]; then
      return ${returncode}
    fi
    vout=$(echo "${vin_txid_vout}" | tr -d '"' | cut -d '-' -f2)
    trace "[compute_vin_total_amount] vout=${vout}"
    vin_vout_amount=$(echo "${vin_raw_tx}" | jq ".result.vout[] | select(.n == ${vout}) | .value" | awk '{ printf "%.8f", $0 }')
    trace "[compute_vin_total_amount] vin_vout_amount=${vin_vout_amount}"
    vin_total_amount=$(awk "BEGIN { printf(\"%.8f\", ${vin_total_amount}+${vin_vout_amount}); exit}")
    trace "[compute_vin_total_amount] vin_total_amount=${vin_total_amount}"
  done

  echo "${vin_total_amount}"

  return 0
}

case "${0}" in *computefees.sh) compute_vin_total_amount "$@";; esac
