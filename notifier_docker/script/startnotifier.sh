#!/bin/sh
. ./trace.sh

trace "Starting mosquitto and subscribing to the notifier topic..."

if [ "${FEATURE_TELEGRAM}" = "true" ]; then
  trace "[startnotifier] Waiting for PostgreSQL to be ready..."
  while [ ! -f "/container_monitor/postgres_ready" ]; do trace "[startnotifier] PostgreSQL not ready" ; sleep 10 ; done
  trace "[startnotifier] PostgreSQL ready!"
fi

exec sh -c 'mosquitto_sub -h broker -t notifier | ./requesthandler.sh'
