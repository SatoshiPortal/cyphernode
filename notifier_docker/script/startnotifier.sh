#!/bin/sh
. ./trace.sh

wait_for_broker() {
  trace "[startnotifier-wait_for_broker] Waiting for broker to be ready"

  while true ; do ping -c 1 broker ; [ "$?" -eq "0" ] && break ; sleep 5; done
}

trace "Starting mosquitto and subscribing to the notifier topic..."

if [ "${FEATURE_TELEGRAM}" = "true" ]; then
  trace "[startnotifier] Waiting for PostgreSQL to be ready..."
  while [ ! -f "/container_monitor/postgres_ready" ]; do trace "[startnotifier] PostgreSQL not ready" ; sleep 10 ; done
  trace "[startnotifier] PostgreSQL ready!"
fi

# Wait for broker to be ready
wait_for_broker

exec sh -c 'mosquitto_sub -h broker -t notifier | ./requesthandler.sh'
