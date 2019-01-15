#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./importaddress.sh
. ./confirmation.sh

manage_not_imported()
{
	# When we tried to import watched addresses in the watching node,
	# if it didn't succeed, we try again here.

	trace "[Entering manage_not_imported()]"

	local watches=$(sql 'SELECT address FROM watching WHERE watching AND NOT imported')
	trace "[manage_not_imported] watches=${watches}"

	local result
	local returncode
	local IFS=$'\n'
	for address in ${watches}
	do
		result=$(importaddress_rpc "${address}")
		returncode=$?
		trace_rc ${returncode}
		if [ "${returncode}" -eq 0 ]; then
			sql "UPDATE watching SET imported=1 WHERE address=\"${address}\""
		fi
	done

	return 0
}

manage_missed_conf()
{
	# Maybe we missed confirmations, because we were down or no network or
	# whatever, so we look at what might be missed and do confirmations.

	trace "[Entering manage_missed_conf()]"

#	local watches=$(sql 'SELECT address FROM watching WHERE txid IS NULL AND watching AND imported')
	#local watches=$(sql 'SELECT address FROM watching LEFT JOIN watching_tx ON id = watching_id WHERE watching AND imported AND tx_id IS NULL')
	local watches=$(sql 'SELECT address FROM watching w LEFT JOIN watching_tx ON w.id = watching_id LEFT JOIN tx t ON t.id = tx_id WHERE watching AND imported AND (tx_id IS NULL OR t.confirmations=0)')
	trace "[manage_missed_conf] watches=${watches}"
	if [ ${#watches} -eq 0 ]; then
		trace "[manage_missed_conf] Nothing missed!"
		return 0
	fi

	local addresses
	local data
	local result
	local returncode
	local IFS=$'\n'
	for address in ${watches}
	do
		if [ -z ${addresses} ]; then
			addresses="[\"${address}\""
		else
			addresses="${addresses},\"${address}\""
		fi
	done
	addresses="${addresses}]"

	# Watching addresses with UTXO are transactions being watched that went through without us knowing it, we missed the conf
	data="{\"method\":\"listunspent\",\"params\":[0, 9999999, ${addresses}]}"
	local unspents
	unspents=$(send_to_watcher_node ${data})
	returncode=$?
	trace_rc ${returncode}
	if [ "${returncode}" -ne 0 ]; then
		return ${returncode}
	fi

#  | tr -d '"'
	local txids=$(echo "${unspents}" | jq ".result[].txid" | tr -d '"')
	for txid in ${txids}
	do
		confirmation "${txid}"
	done

	return 0

}

case "${0}" in *manage_missed_conf.sh) manage_not_imported $@; manage_missed_conf $@;; esac
