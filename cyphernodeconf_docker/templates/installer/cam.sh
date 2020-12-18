#!/bin/sh

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"
docker run --rm -v $current_path:/dist --workdir="/dist" --entrypoint /app/cam cyphernode/cyphernodeconf:<%= conf_version %> $*
