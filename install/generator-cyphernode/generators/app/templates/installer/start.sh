#!/bin/sh

# run as user <%= username %>
export USER=$(id -u <%= run_as_different_user?username:default_username %>):$(id -g <%= run_as_different_user?username:default_username %>)
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
-v <%= proxy_datapath %>:/proxy \
--network cyphernodenet alpine:3.8 /testfeatures.sh

echo "Point your favorite browser to one of the following URLs to access Cyphernode's status page:"
echo
echo
