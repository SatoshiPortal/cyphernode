#!/bin/sh

. ./trace.sh

get_prop()
{
	trace "Entering get_prop()..."

	local property=${1}
	trace "[get_prop] property=${property}"

	local value=$(grep "${property}" config.properties | cut -d'=' -f2)

	trace "[get_prop] value=${value}"

	echo ${value}
}
