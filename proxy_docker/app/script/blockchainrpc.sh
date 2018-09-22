#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

get_best_block_hash()
{
	trace "Entering get_best_block_hash()..."

	local data='{"method":"getbestblockhash"}'
	send_to_watcher_node "${data}"
	return $?
}

getestimatesmartfee()
{
	trace "Entering getestimatesmartfee()..."

	local nb_blocks=${1}
	trace "[getestimatesmartfee] nb_blocks=${nb_blocks}"
	send_to_watcher_node "{\"method\":\"estimatesmartfee\",\"params\":[${nb_blocks}]}" | jq ".result.feerate" | awk '{ printf "%.8f", $0 }'
	return $?
}

get_block_info()
{
	trace "Entering get_block_info()..."

	local block_hash=${1}
	trace "[get_block_info] block_hash=${block_hash}"
	local data="{\"method\":\"getblock\",\"params\":[\"${block_hash}\"]}"
	trace "[get_block_info] data=${data}"
	send_to_watcher_node "${data}"
	return $?
}

get_best_block_info()
{
	trace "Entering get_best_block_info()..."

	local block_hash=$(echo "$(get_best_block_hash)" | jq ".result" | tr -d '"')
	trace "[get_best_block_info] block_hash=${block_hash}"
	get_block_info ${block_hash}
	return $?
}

get_rawtransaction()
{
	trace "Entering get_rawtransaction()..."

	local txid=${1}
	trace "[get_rawtransaction] txid=${txid}"

	local rawtx
	rawtx=$(sql "SELECT raw_tx FROM tx WHERE txid=\"${txid}\"")
	if [ -z ${rawtx} ]; then
		trace "[get_rawtransaction] rawtx not found in DB, let's fetch the Bitcoin node"
		local data="{\"method\":\"getrawtransaction\",\"params\":[\"${txid}\",true]}"
		trace "[get_rawtransaction] data=${data}"
		send_to_watcher_node "${data}"
		return $?
	else
		trace "[get_rawtransaction] rawtx found in DB, no need to fetch the Bitcoin node"
		echo ${rawtx}
		return 0
	fi
}

get_transaction()
{
	trace "Entering get_transaction()..."

	local txid=${1}
	trace "[get_transaction] txid=${txid}"
	local data="{\"method\":\"gettransaction\",\"params\":[\"${txid}\",true]}"
	trace "[get_transaction] data=${data}"
	send_to_watcher_node "${data}"
	return $?
}
