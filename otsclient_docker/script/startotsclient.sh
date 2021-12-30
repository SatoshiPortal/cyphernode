#!/bin/sh

exec nc -vlkp${OTSCLIENT_LISTENING_PORT} -e ./requesthandler.sh
