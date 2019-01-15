#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh
. ./sql.sh
. ./blockchainrpc.sh

compute_fees()
{
	local pruned=${WATCHER_BTC_NODE_PRUNED}
	if [ "${pruned}" = "true" ]; then
		trace "[compute_fees]  pruned=${pruned}"
		# We want null instead of 0.00000000 in this case.
		echo "null"
		exit 0
	fi

	local txid=${1}

	local tx_raw_details=$(cat rawtx-${txid}.blob)
	trace "[compute_fees]  tx_raw_details=${tx_raw_details}"
	local vin_total_amount=$(compute_vin_total_amount "${tx_raw_details}")

	local vout_total_amount=0
	local vout_value
	local vout_values=$(echo "${tx_raw_details}" | jq ".result.vout[].value")
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

compute_vin_total_amount()
{
	trace "Entering compute_vin_total_amount()..."

	local main_tx=${1}
	local vin_txids_vout=$(echo "${main_tx}" | jq '.result.vin[] | ((.txid + "-") + (.vout | tostring))')
	trace "[compute_vin_total_amount] vin_txids_vout=${vin_txids_vout}"
	local returncode
	local vin_txid_vout
	local vin_txid
	local vin_raw_tx
	local vin_vout_amount=0
	local vout
	local vin_total_amount=0
	local vin_hash
	local vin_confirmations
	local vin_timereceived
	local vin_vsize
	local vin_blockhash
	local vin_blockheight
	local vin_blocktime
	local txid_already_inserted=true

	for vin_txid_vout in ${vin_txids_vout}
	do
		vin_txid=$(echo "${vin_txid_vout}" | tr -d '"' | cut -d '-' -f1)
		# Check if we already have the tx in our DB
		vin_raw_tx=$(sql "SELECT raw_tx FROM tx WHERE txid=\"${vin_txid}\"")
		if [ -z "${vin_raw_tx}" ]; then
			txid_already_inserted=false
			vin_raw_tx=$(get_rawtransaction "${vin_txid}")
			returncode=$?
			if [ "${returncode}" -ne 0 ]; then
				return ${returncode}
			fi
		fi
		vout=$(echo "${vin_txid_vout}" | tr -d '"' | cut -d '-' -f2)
		trace "[compute_vin_total_amount] vout=${vout}"
		vin_vout_amount=$(echo "${vin_raw_tx}" | jq ".result.vout[] | select(.n == ${vout}) | .value" | awk '{ printf "%.8f", $0 }')
		trace "[compute_vin_total_amount] vin_vout_amount=${vin_vout_amount}"
		vin_total_amount=$(awk "BEGIN { printf(\"%.8f\", ${vin_total_amount}+${vin_vout_amount}); exit}")
		trace "[compute_vin_total_amount] vin_total_amount=${vin_total_amount}"
		vin_hash=$(echo "${vin_raw_tx}" | jq ".result.hash")
		vin_confirmations=$(echo "${vin_raw_tx}" | jq ".result.confirmations")
		vin_timereceived=$(echo "${vin_raw_tx}" | jq ".result.time")
		vin_size=$(echo "${vin_raw_tx}" | jq ".result.size")
		vin_vsize=$(echo "${vin_raw_tx}" | jq ".result.vsize")
		vin_blockhash=$(echo "${vin_raw_tx}" | jq ".result.blockhash")
		vin_blockheight=$(echo "${vin_raw_tx}" | jq ".result.blockheight")
		vin_blocktime=$(echo "${vin_raw_tx}" | jq ".result.blocktime")

		# Let's insert the vin tx in the DB just in case it would be useful
		if ! ${txid_already_inserted}; then
			# Sometimes raw tx are too long to be passed as paramater, so let's write
			# it to a temp file for it to be read by sqlite3 and then delete the file
			echo "${vin_raw_tx}" > rawtx-${vin_txid}.blob
			sql "INSERT OR IGNORE INTO tx (txid, hash, confirmations, timereceived, size, vsize, blockhash, blockheight, blocktime, raw_tx) VALUES (\"${vin_txid}\", ${vin_hash}, ${vin_confirmations}, ${vin_timereceived}, ${vin_size}, ${vin_vsize}, ${vin_blockhash}, ${vin_blockheight}, ${vin_blocktime}, readfile('rawtx-${vin_txid}.blob'))"
			trace_rc $?
			rm rawtx-${vin_txid}.blob
			txid_already_inserted=true
		fi
	done

	echo "${vin_total_amount}"

	return 0
}

case "${0}" in *computefees.sh) compute_vin_total_amount $@;; esac
