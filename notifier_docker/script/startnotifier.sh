#!/bin/sh

. ./trace.sh

mosquitto_sub -h broker -t notifier | ./requesthandler.sh
