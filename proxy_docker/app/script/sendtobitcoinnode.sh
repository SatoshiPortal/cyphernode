#!/bin/sh

. ./trace.sh

send_to_watcher_node()
{
	trace "Entering send_to_watcher_node()..."
	send_to_bitcoin_node ${WATCHER_NODE_RPC_URL} watcher_btcnode_curlcfg.properties $@
	local returncode=$?
	trace_rc ${returncode}
	return ${returncode}
}

send_to_spender_node()
{
	trace "Entering send_to_spender_node()..."
	send_to_bitcoin_node ${SPENDER_NODE_RPC_URL} spender_btcnode_curlcfg.properties $@
	local returncode=$?
	trace_rc ${returncode}
	return ${returncode}
}

send_to_bitcoin_node()
{
	trace "Entering send_to_bitcoin_node()..."
	local returncode
	local result
	local errorstring
	local node_url=${1}
	local configfile=${2}
	local data=${3}

	trace "[send_to_bitcoin_node] curl -s --config ${configfile} -H \"Content-Type: application/json\" -d \"${data}\" ${node_url}"
	result=$(curl -s --config ${configfile} -H "Content-Type: application/json" -d "${data}" ${node_url})
	returncode=$?
	trace_rc ${returncode}
	trace "[send_to_bitcoin_node] result=${result}"

	if [ "${returncode}" -eq 0 ]; then
		# Node responded, let's see if we got an error message from the node
		# jq -e will have a return code of 1 if the supplied tag is null.
		errorstring=$(echo "${result}" | jq -e ".error")
		if [ "$?" -eq "0" ]; then
			# Error tag not null, so there's an error
			trace "[send_to_bitcoin_node] Node responded, error found in response: ${errorstring}"
			returncode=1
		else
			trace "[send_to_bitcoin_node] Node responded, no error found in response, yayy!"
		fi
	fi

	# Output response to stdout before exiting with return code
	echo "${result}"

	trace_rc ${returncode}
	return ${returncode}
}

case "${0}" in *sendtobitcoinnode.sh) send_to_bitcoin_node $@;; esac
