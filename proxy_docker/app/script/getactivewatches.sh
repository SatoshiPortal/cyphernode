#!/bin/sh

. ./trace.sh
. ./sql.sh

getactivewatches() {
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

getactivewatchesbyxpub() {
  trace "Entering getactivewatchesbyxpub()..."

  local xpub=${1}
  local returncode

  getactivewatchesxpub "pub32" ${xpub}
  returncode=$?
	trace_rc ${returncode}

  return ${returncode}
}

getactivewatchesbylabel() {
  trace "Entering getactivewatchesbylabel()..."

  local label=${1}
  local returncode

  getactivewatchesxpub "label" ${label}
  returncode=$?
	trace_rc ${returncode}

  return ${returncode}
}

getactivewatchesxpub() {
  trace "Entering getactivewatchesxpub()..."

  local where=${1}
  trace "[getactivewatchesxpub] where=${where}"
  local value=${2}
  trace "[getactivewatchesxpub] value=${value}"
	local watches
	watches=$(sql "SELECT id, address, imported, callback0conf, callback1conf, inserted_ts, derivation_path, pub32_index FROM watching, watching_by_pub32 w32 WHERE watching_by_pub32_id = w32.id AND ${where} = \"${value}\" AND watching AND NOT calledback1conf")
	returncode=$?
	trace_rc ${returncode}

	local id
	local address
	local imported
	local inserted
	local cb0conf_url
	local cb1conf_url
	local timestamp
  local derivation_path
  local pub32_index
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
		trace "[getactivewatchesxpub] row=${row}"
		id=$(echo "${row}" | cut -d '|' -f1)
		trace "[getactivewatchesxpub] id=${id}"
		address=$(echo "${row}" | cut -d '|' -f2)
		trace "[getactivewatchesxpub] address=${address}"
		imported=$(echo "${row}" | cut -d '|' -f3)
		trace "[getactivewatchesxpub] imported=${imported}"
		cb0conf_url=$(echo "${row}" | cut -d '|' -f4)
		trace "[getactivewatchesxpub] cb0conf_url=${cb0conf_url}"
		cb1conf_url=$(echo "${row}" | cut -d '|' -f5)
		trace "[getactivewatchesxpub] cb1conf_url=${cb1conf_url}"
		timestamp=$(echo "${row}" | cut -d '|' -f6)
		trace "[getactivewatchesxpub] timestamp=${timestamp}"
    derivation_path=$(echo "${row}" | cut -d '|' -f7)
		trace "[getactivewatchesxpub] derivation_path=${derivation_path}"
    pub32_index=$(echo "${row}" | cut -d '|' -f8)
		trace "[getactivewatchesxpub] pub32_index=${pub32_index}"

		data="{\"id\":\"${id}\","
		data="${data}\"address\":\"${address}\","
		data="${data}\"imported\":\"${imported}\","
		data="${data}\"unconfirmedCallbackURL\":\"${cb0conf_url}\","
    data="${data}\"confirmedCallbackURL\":\"${cb1conf_url}\","
    data="${data}\"watching_since\":\"${timestamp}\","
    data="${data}\"derivation_path\":\"${derivation_path}\","
		data="${data}\"pub32_index\":\"${pub32_index}\"}"
		trace "[getactivewatchesxpub] data=${data}"

		echo -n "${data}"
	done

	echo "]}"

	return ${returncode}
}
