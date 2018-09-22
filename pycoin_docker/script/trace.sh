#!/bin/sh

trace()
{
	if [ -n "${TRACING}" ]; then
		echo "$(date -Is) ${1}" > /dev/stderr
	fi
}

trace_rc()
{
	if [ -n "${TRACING}" ]; then
		echo "$(date -Is) Last return code: ${1}" > /dev/stderr
	fi
}
