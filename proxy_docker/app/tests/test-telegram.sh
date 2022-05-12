#!/bin/sh

# Tests the notify_telegram (in notify.sh) function by calling it directly - not going through the proxy, there is no endpoint.

cd ..
. ./notify.sh

echo "Calling notify_telegram..."

notify_telegram "Unit testing notify_telegram at `date -u +"%FT%H%MZ"`"

echo "Done..."

