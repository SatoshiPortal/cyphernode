#!/bin/sh

. notify.sh

TRACING=1

export TRACING

echo "Calling notify_telegram..."

notify_telegram "{\"text\":\"Unit testing notify_telegram at `date -u +"%FT%H%MZ"`\"}"

echo "Done..."


