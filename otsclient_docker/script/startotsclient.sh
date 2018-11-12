#!/bin/sh

export TRACING
export OTSCLIENT_LISTENING_PORT

nc -vlkp${OTSCLIENT_LISTENING_PORT} -e ./requesthandler.sh
