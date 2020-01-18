#!/usr/bin/env bash

# can be specified in the docker-compose file with
# SERVICE_PRECONDITION: "host1:9870 host2:9864"
/waitforit.sh
if [ $? -eq 1 ]; then
    exit 1;
fi

exec su-exec $@
