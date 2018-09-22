#!/bin/sh

. ./trace.sh
. ./utils.sh

deriveindex()
{
	trace "Entering deriveindex()..."

	local index=${1}
	trace "[deriveindex] index=${index}"

	local pub32=$(get_prop "derivation.pub32")
	local path=$(get_prop "derivation.path" | sed -En "s/n/${index}/p")
	#	pub32=$(grep "derivation.pub32" config.properties | cut -d'=' -f2)
	#	path=$(grep "derivation.path" config.properties | cut -d'=' -f2 | sed -En "s/n/${index}/p")

	local data="{\"pub32\":\"${pub32}\",\"path\":\"${path}\"}"
	trace "[deriveindex] data=${data}"

	send_to_pycoin "${data}"
	return $?
}

send_to_pycoin()
{
	trace "Entering send_to_pycoin()..."

	local data=${1}
	local result
	local returncode

	trace "[send_to_pycoin] curl -s -H \"Content-Type: application/json\" -d \"${data}\" ${PYCOIN_CONTAINER}/derive"

	result=$(curl -s -H "Content-Type: application/json" -d "${data}" ${PYCOIN_CONTAINER}/derive)
	returncode=$?
	trace_rc ${returncode}
	trace "[send_to_pycoin] result=${result}"

	# Output response to stdout before exiting with return code
	echo "${result}"

	trace_rc ${returncode}
	return ${returncode}

}
