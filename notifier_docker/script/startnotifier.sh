#!/bin/sh
. ./trace.sh

trace "Starting mosquitto and subscribing to the notifier topic..."

exec sh -c 'mosquitto_sub -h broker -t notifier | ./requesthandler.sh'
