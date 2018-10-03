#!/bin/sh

. ./trace.sh

# this will run configure.sh of the specified package inside a 
# cyphernodeconf container. This way we ensure we have the right
# environment and do not pollute the host machine with utility
# commands not needed for runtime

cyphernodeconf_configure() {
	PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
	DATA_PATH=$PWD/../data
	SCRIPT_PATH=$PWD/../$1/script
	VOLUME_PATH=/tmp
	docker run -v $VOLUME_PATH:/volume \
	           -v $DATA_PATH:/data \
	           -v $SCRIPT_PATH:/script\
	           --log-driver=none\
	           --rm -it cyphernodeconf:latest
}