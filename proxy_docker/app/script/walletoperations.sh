#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

spend() {
	trace "Entering spend()..."

	local data
	local request=${1}
	local address=$(echo "${request}" | jq ".address" | tr -d '"')
	trace "[spend] address=${address}"
	local amount=$(echo "${request}" | jq ".amount" | awk '{ printf "%.8f", $0 }')
	trace "[spend] amount=${amount}"
	local response
	local id_inserted

	response=$(send_to_spender_node "{\"method\":\"sendtoaddress\",\"params\":[\"${address}\",${amount}]}")
	local returncode=$?
	trace_rc ${returncode}
	trace "[spend] response=${response}"

	if [ "${returncode}" -eq 0 ]; then
		local txid=$(echo ${response} | jq ".result" | tr -d '"')
		trace "[spend] txid=${txid}"

		# Let's insert the txid in our little DB to manage the confirmation and tell it's not a watching address
		sql "INSERT OR IGNORE INTO tx (txid) VALUES (\"${txid}\")"
		trace_rc $?
		id_inserted=$(sql "SELECT id FROM tx WHERE txid=\"${txid}\"")
		trace_rc $?
		sql "INSERT OR IGNORE INTO recipient (address, amount, tx_id) VALUES (\"${address}\", ${amount}, ${id_inserted})"
		trace_rc $?

		data="{\"status\":\"accepted\""
		data="${data},\"hash\":\"${txid}\"}"
	else
		local message=$(echo "${response}" | jq -e ".error.message")
		data="{\"message\":${message}}"
	fi

	trace "[spend] responding=${data}"
	echo "${data}"

	return ${returncode}
}

getbalance() {
	trace "Entering getbalance()..."

	local response
	local data='{"method":"getbalance"}'
	response=$(send_to_spender_node "${data}")
	local returncode=$?
	trace_rc ${returncode}
	trace "[getbalance] response=${response}"

	if [ "${returncode}" -eq 0 ]; then
		local balance=$(echo ${response} | jq ".result")
		trace "[getbalance] balance=${balance}"

		data="{\"balance\":${balance}}"
	else
		trace "[getbalance] Coudn't get balance!"
		data=""
	fi

	trace "[getbalance] responding=${data}"
	echo "${data}"

	return ${returncode}
}

getnewaddress() {
	trace "Entering getnewaddress()..."

	local response
	local data='{"method":"getnewaddress"}'
	response=$(send_to_spender_node "${data}")
	local returncode=$?
	trace_rc ${returncode}
	trace "[getnewaddress] response=${response}"

	if [ "${returncode}" -eq 0 ]; then
		local address=$(echo ${response} | jq ".result")
		trace "[getnewaddress] address=${address}"

		data="{\"address\":${address}}"
	else
		trace "[getnewaddress] Coudn't get a new address!"
		data=""
	fi

	trace "[getnewaddress] responding=${data}"
	echo "${data}"

	return ${returncode}
}

addtobatching() {
	trace "Entering addtobatching()..."

	local address=${1}
	trace "[addtobatching] address=${address}"
	local amount=${2}
	trace "[addtobatching] amount=${amount}"

	sql "INSERT OR IGNORE INTO recipient (address, amount) VALUES (\"${address}\", ${amount})"
	returncode=$?
	trace_rc ${returncode}

	return ${returncode}
}

batchspend() {
	trace "Entering batchspend()..."

	local data
	local response
	local recipientswhere
	local recipientsjson
	local id_inserted

	# We will batch all the addresses in DB without a TXID
	local batching=$(sql 'SELECT address, amount FROM recipient WHERE tx_id IS NULL')
	trace "[batchspend] batching=${batching}"

	local returncode
	local address
	local amount
	local notfirst=false
	local IFS=$'\n'
	for row in ${batching}
	do
		trace "[batchspend] row=${row}"
		address=$(echo "${row}" | cut -d '|' -f1)
		trace "[batchspend] address=${address}"
		amount=$(echo "${row}" | cut -d '|' -f2)
		trace "[batchspend] amount=${amount}"

		if ${notfirst}; then
			recipientswhere="${recipientswhere},"
			recipientsjson="${recipientsjson},"
		else
			notfirst=true
		fi

		recipientswhere="${recipientswhere}\"${address}\""
		recipientsjson="${recipientsjson}\"${address}\":${amount}"
	done

	response=$(send_to_spender_node "{\"method\":\"sendmany\",\"params\":[\"\", {${recipientsjson}}]}")
	returncode=$?
	trace_rc ${returncode}
	trace "[batchspend] response=${response}"

	if [ "${returncode}" -eq 0 ]; then
		local txid=$(echo ${response} | jq ".result" | tr -d '"')
		trace "[batchspend] txid=${txid}"

		# Let's insert the txid in our little DB to manage the confirmation and tell it's not a watching address
		sql "INSERT OR IGNORE INTO tx (txid) VALUES (\"${txid}\")"
		returncode=$?
		trace_rc ${returncode}
		if [ "${returncode}" -eq 0 ]; then
			id_inserted=$(sql "SELECT id FROM tx WHERE txid=\"${txid}\"")
			trace "[batchspend] id_inserted: ${id_inserted}"
			sql "UPDATE recipient SET tx_id=${id_inserted} WHERE address IN (${recipientswhere})"
			trace_rc $?
		fi

		data="{\"status\":\"accepted\""
		data="${data},\"hash\":\"${txid}\"}"
	else
		local message=$(echo "${response}" | jq -e ".error.message")
		data="{\"message\":${message}}"
	fi

	trace "[batchspend] responding=${data}"
	echo "${data}"

	return ${returncode}
}

create_wallet() {
  trace "[Entering create_wallet()]"

  local walletname=${1}

  local rpcstring="{\"method\":\"createwallet\",\"params\":[\"${walletname}\",true]}"
  trace "[create_wallet] rpcstring=${rpcstring}"

  local result
  result=$(send_to_watcher_node ${rpcstring})
  local returncode=$?

  echo "${result}"

  return ${returncode}
}

