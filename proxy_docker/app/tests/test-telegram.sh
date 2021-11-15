#!/bin/sh

cd ..
. ./notify.sh

echo "Calling notify_telegram..."

notify_telegram "{\"text\":\"Unit testing notify_telegram at `date -u +"%FT%H%MZ"`\"}"

echo "Done..."

