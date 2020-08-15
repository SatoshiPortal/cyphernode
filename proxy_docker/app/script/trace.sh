#!/bin/sh

trace()
{
  if [ -n "${TRACING}" ]; then
    local str="$(date -Is) $$ ${1}"
    echo "${str}" 1>&2
    echo "${str}" >> /cnlogs/proxy.log
  fi
}

trace_rc()
{
  if [ -n "${TRACING}" ]; then
    local str="$(date -Is) $$ Last return code: ${1}"
    echo "${str}" 1>&2
    echo "${str}" >> /cnlogs/proxy.log
  fi
}
