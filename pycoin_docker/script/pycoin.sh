#!/bin/sh

. ./trace.sh

derive()
{
	trace "Entering derive()..."

	local request=${1}
	local pub32=$(echo "${request}" | jq ".pub32" | tr -d '"')
	local path=$(echo "${request}" | jq ".path" | tr -d '"')

	local result
	local returncode
	trace "[derive] path=${path}"
	trace "[derive] pub32=${pub32}"

	result=$(ku -n BTC -s ${path} -a E:${pub32})

	returncode=$?
	trace_rc ${returncode}
	trace "[derive] result=${result}"

	local notfirst=false

	echo -n "{\"addresses\":["

	local IFS=$'\n'
	for address in ${result}
	do
		if ${notfirst}; then
			echo ","
		else
			notfirst=true
		fi
		trace "[derive] address=${address}"

		data="{\"address\":\"${address}\"}"
		trace "[derive] data=${data}"

		echo -n "${data}"
	done

	echo "]}"

	return ${returncode}
}
