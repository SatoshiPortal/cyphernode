#!/bin/sh

trace()
{
	if [ -n "${TRACING}" ]; then
		echo "$(date -Is) ${1}" 1>&2
	fi
}

trace_rc()
{
	if [ -n "${TRACING}" ]; then
		echo "$(date -Is) Last return code: ${1}" 1>&2
	fi
}
