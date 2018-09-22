#!/bin/sh

. ./trace.sh

ln_create_invoice()
{
	trace "Entering ln_create_invoice()..."

	local result

	local request=${1}
	local msatoshi=$(echo "${request}" | jq ".msatoshi" | tr -d '"')
	trace "[ln_create_invoice] msatoshi=${msatoshi}"
	local label=$(echo "${request}" | jq ".label")
	trace "[ln_create_invoice] label=${label}"
	local description=$(echo "${request}" | jq ".description")
	trace "[ln_create_invoice] description=${description}"
	local expiry=$(echo "${request}" | jq ".expiry" | tr -d '"')
	trace "[ln_create_invoice] expiry=${expiry}"

	result=$(./lightning-cli invoice ${msatoshi} "${label}" "${description}" ${expiry})
	returncode=$?
	trace_rc ${returncode}
	trace "[ln_create_invoice] result=${result}"

	echo "${result}"

	return ${returncode}
}

ln_getinfo()
{
	trace "Entering ln_get_info()..."

	local result

	result=$(./lightning-cli getinfo)
	returncode=$?
	trace_rc ${returncode}
	trace "[ln_getinfo] result=${result}"

	echo "${result}"

	return ${returncode}
}

ln_pay() {
	trace "Entering ln_pay()..."

	local result

	local request=${1}
	local bolt11=$(echo "${request}" | jq ".bolt11" | tr -d '"')
	trace "[ln_pay] bolt11=${bolt11}"
	local expected_msatoshi=$(echo "${request}" | jq ".expected_msatoshi")
	trace "[ln_pay] expected_msatoshi=${expected_msatoshi}"
	local expected_description=$(echo "${request}" | jq ".expected_description")
	trace "[ln_pay] expected_description=${expected_description}"

	result=$(./lightning-cli decodepay ${bolt11})

	local invoice_msatoshi=$(echo "${result}" | jq ".msatoshi")
	trace "[ln_pay] invoice_msatoshi=${invoice_msatoshi}"
	local invoice_description=$(echo "${result}" | jq ".description")
	trace "[ln_pay] invoice_description=${invoice_description}"

	if [ "${expected_msatoshi}" != "${invoice_msatoshi}" ]; then
		result="{\"result\":\"error\",\"expected_msatoshi\":${expected_msatoshi},\"invoice_msatoshi\":${invoice_msatoshi}}"
		returncode=1
	elif [ "${expected_description}" != "${invoice_description}" ]; then
		result="{\"result\":\"error\",\"expected_description\":${expected_description},\"invoice_description\":${invoice_description}}"
		returncode=1
	else
		result=$(./lightning-cli pay ${bolt11})
		returncode=$?
		trace_rc ${returncode}
	fi
	trace "[ln_pay] result=${result}"

	echo "${result}"

	return ${returncode}
}

ln_newaddr()
{
	trace "Entering ln_newaddr()..."

	local result

	call_lightningd newaddr
	result=$(./lightning-cli newaddr)
	returncode=$?
	trace_rc ${returncode}
	trace "[ln_newaddr] result=${result}"

	echo "${result}"

	return ${returncode}
}

case "${0}" in *call_lightningd.sh) call_lightningd $@;; esac
