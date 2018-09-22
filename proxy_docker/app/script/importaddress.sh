#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

importaddress_rpc()
{
	trace "[Entering importaddress_rpc()]"

	local address=${1}
	local data="{\"method\":\"importaddress\",\"params\":[\"${address}\",\"\",false]}"
	local result
	result=$(send_to_watcher_node ${data})
	local returncode=$?

	echo "${result}"

	return ${returncode}
}

case "${0}" in *importaddress.sh) importaddress_rpc $@;; esac
