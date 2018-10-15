#!/bin/sh

trace()
{
	if [ -n "${TRACING}" ]; then
		echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] ${1}" 1>&2
	fi
}

trace_rc()
{
	if [ -n "${TRACING}" ]; then
		echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] Last return code: ${1}" 1>&2
	fi
}
