#!/bin/sh

. ./trace.sh

# this will run configure.sh of the specified package inside a 
# cyphernodeconf container. This way we ensure we have the right
# environment and do not pollute the host machine with utility
# commands not needed for runtime

cyphernodeconf_configure() {
  local current_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

  docker run -v $current_path/../data:/data \
             --log-driver=none\
             --rm -it cyphernodeconf:latest
}