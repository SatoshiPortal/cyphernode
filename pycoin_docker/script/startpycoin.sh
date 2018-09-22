#!/bin/sh

export TRACING
export PYCOIN_LISTENING_PORT

nc -vlkp${PYCOIN_LISTENING_PORT} -e ./requesthandler.sh
