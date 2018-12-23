#!/bin/sh

<% if (run_as_different_user) { %>
OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
  printf "\r\n\033[0;91m'Run as another user' feature is not supported on OSX.  User <%= default_username %> will be used to run Cyphernode.\033[0m\r\n\r\n"
  export USER=$(id -u <%= default_username %>):$(id -g <%= default_username %>)
else
  export USER=$(id -u <%= username %>):$(id -g <%= username %>)
fi
<% } else { %>
export USER=$(id -u <%= default_username %>):$(id -g <%= default_username %>)
<% } %>

export ARCH=$(uname -m)
current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"

<% if (docker_mode == 'swarm') { %>
docker stack deploy -c $current_path/docker-compose.yaml cyphernode
<% } else if(docker_mode == 'compose') { %>
docker-compose -f $current_path/docker-compose.yaml up -d --remove-orphans
<% } %>

arch=$(uname -m)
case "${arch}" in arm*)
  printf "\r\n\033[1;31mSince we're on a slow RPi, let's give Docker 30 more seconds before performing our tests...\033[0m\r\n"
  sleep 30
;;
esac

echo "EXIT_STATUS=1" > $current_path/exitStatus.sh

# Will test if Cyphernode is fully up and running...
docker run --rm -it -v $current_path/testfeatures.sh:/testfeatures.sh \
-v ~/.cyphernode/gatekeeper:/gatekeeper \
-v $current_path/exitStatus.sh:/exitStatus.sh \
--network cyphernodenet alpine:3.8 /testfeatures.sh

if [[ -f $current_path/exitStatus.sh ]]; then
  . $current_path/exitStatus.sh
  rm $current_path/exitStatus.sh
fi

if [[ ! $EXIT_STATUS == 0 ]]; then
  exec ./stop.sh
  exit 1
fi



printf "\r\n\033[0;92mDepending on your current location and DNS settings, point your favorite browser to one of the following URLs to access Cyphernode's status page:\r\n"
printf "\r\n"
printf "\033[0;95m<% cns.forEach(cn => { %><%= ('https://' + cn + '/status/\\r\\n') %><% }) %>\033[0m\r\n"
