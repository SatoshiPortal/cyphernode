#!/bin/bash

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"

docker run --rm -it -v $current_path/tgsetup.sh:/tgsetup.sh \
-v $current_path:/dist \
-e PGPASSFILE=/dist/cyphernode/proxy/pgpass \
--network cyphernodenet eclipse-mosquitto:<%= mosquitto_version %> /tgsetup.sh

