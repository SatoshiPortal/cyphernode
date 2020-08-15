#!/bin/sh

trace()
{
  if [ -n "${TRACING}" ]; then
    local str="[$(date +%Y-%m-%dT%H:%M:%S%z)] $$ $*"
    echo "${str}" 1>&2
    echo "${str}" >> /cnlogs/gatekeeper.log
  fi
}
