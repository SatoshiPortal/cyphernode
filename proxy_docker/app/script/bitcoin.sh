#!/bin/sh

. ./trace.sh

deriveindex()
{
	trace "Entering deriveindex()..."

	local index=${1}
	trace "[deriveindex] index=${index}"

	local pub32=$DERIVATION_PUB32
	local path=$(echo -e "$DERIVATION_PATH" | sed -En "s/n/${index}/p")
	#	pub32=$(grep "derivation.pub32" config.properties | cut -d'=' -f2)
	#	path=$(grep "derivation.path" config.properties | cut -d'=' -f2 | sed -En "s/n/${index}/p")

	local data="{\"pub32\":\"${pub32}\",\"path\":\"${path}\"}"
	trace "[deriveindex] data=${data}"

	send_to_pycoin "${data}"
	return $?
}

derivepubpath() {
	trace "Entering derivepubpath()..."

	# {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}

	send_to_pycoin $1
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