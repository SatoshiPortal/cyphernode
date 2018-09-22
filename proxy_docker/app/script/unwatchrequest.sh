#!/bin/sh

. ./trace.sh
. ./sql.sh

unwatchrequest()
{
	trace "Entering unwatchrequest()..."

	local request=${1}
	local address=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)
	local returncode
	trace "[unwatchrequest] Unwatch request on address ${address})"

	sql "UPDATE watching SET watching=0 WHERE address=\"${address}\""
	returncode=$?
	trace_rc ${returncode}

	data="{\"event\":\"unwatch\",\"address\":\"${address}\"}"
	trace "[unwatchrequest] responding=${data}"

	echo "${data}"

	return ${returncode}
}

case "${0}" in *unwatchrequest.sh) unwatchrequest $@;; esac
