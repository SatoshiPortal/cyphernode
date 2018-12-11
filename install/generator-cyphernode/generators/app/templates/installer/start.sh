#!/bin/sh

# run as user <%= username %>
export USER=$(id -u <%= run_as_different_user?username:default_username %>):$(id -g <%= run_as_different_user?username:default_username %>)
export ARCH=$(uname -m)

<% if (docker_mode == 'swarm') { %>
docker stack deploy -c docker-compose.yaml cyphernode
<% } else if(docker_mode == 'compose') { %>
docker-compose -f docker-compose.yaml up -d --remove-orphans
<% } %>

# Will test if Cyphernode is fully up and running...
docker run --rm -it -v `pwd`/testfeatures.sh:/testfeatures.sh \
-v `pwd`/gatekeeper/keys.properties:/keys.properties \
-v `pwd`/gatekeeper/cert.pem:/cert.pem \
-v <%= proxy_datapath %>:/proxy \
--network cyphernodenet alpine:3.8 /testfeatures.sh
