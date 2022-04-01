#!/bin/sh

exec nc -vlkp${PYCOIN_LISTENING_PORT} -e ./requesthandler.sh
