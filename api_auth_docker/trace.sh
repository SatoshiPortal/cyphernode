#!/bin/sh

trace()
{
	if [ -n "${TRACING}" ]; then
		echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $$ $*" 2>>/var/log/gatekeeper.log 1>&2
	fi
}
