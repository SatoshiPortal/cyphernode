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

# Will test if Cyphernode is fully up and running...
docker run --rm -it -v $current_path/testfeatures.sh:/testfeatures.sh \
-v $current_path/gatekeeper/keys.properties:/keys.properties \
-v $current_path/gatekeeper/cert.pem:/cert.pem \
-v <%= gatekeeper_datapath %>:/gatekeeper \
--network cyphernodenet alpine:3.8 /testfeatures.sh

printf "\r\n\033[0;92mDepending on your current location and DNS settings, point your favorite browser to one of the following URLs to access Cyphernode's status page:\r\n"
printf "\r\n"
printf "\033[0;95m<% cns.forEach(cn => { %><%= ('https://' + cn + '/status/\\r\\n') %><% }) %>\033[0m\r\n"
