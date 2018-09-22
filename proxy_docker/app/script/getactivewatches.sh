#!/bin/sh

. ./trace.sh
. ./sql.sh

getactivewatches()
{
	trace "Entering getactivewatches()..."

	local watches
	watches=$(sql "SELECT id, address, imported, callback0conf, callback1conf, inserted_ts FROM watching WHERE watching AND NOT calledback1conf")
	returncode=$?
	trace_rc ${returncode}

	local id
	local address
	local imported
	local inserted
	local cb0conf_url
	local cb1conf_url
	local timestamp
	local notfirst=false

	echo -n "{\"watches\":["

	local IFS=$'\n'
	for row in ${watches}
	do
		if ${notfirst}; then
			echo ","
		else
			notfirst=true
		fi
		trace "[getactivewatches] row=${row}"
		id=$(echo "${row}" | cut -d '|' -f1)
		trace "[getactivewatches] id=${id}"
		address=$(echo "${row}" | cut -d '|' -f2)
		trace "[getactivewatches] address=${address}"
		imported=$(echo "${row}" | cut -d '|' -f3)
		trace "[getactivewatches] imported=${imported}"
		cb0conf_url=$(echo "${row}" | cut -d '|' -f4)
		trace "[getactivewatches] cb0conf_url=${cb0conf_url}"
		cb1conf_url=$(echo "${row}" | cut -d '|' -f5)
		trace "[getactivewatches] cb1conf_url=${cb1conf_url}"
		timestamp=$(echo "${row}" | cut -d '|' -f6)
		trace "[getactivewatches] timestamp=${timestamp}"

		data="{\"id\":\"${id}\","
		data="${data}\"address\":\"${address}\","
		data="${data}\"imported\":\"${imported}\","
		data="${data}\"unconfirmedCallbackURL\":\"${cb0conf_url}\","
		data="${data}\"confirmedCallbackURL\":\"${cb1conf_url}\","
		data="${data}\"watching_since\":\"${timestamp}\"}"
		trace "[getactivewatches] data=${data}"

		echo -n "${data}"
	done

	echo "]}"

	return ${returncode}
}

case "${0}" in *getactivewatches.sh) getactivewatches;; esac
