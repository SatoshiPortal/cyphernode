#!/bin/sh

<% if (docker_mode == 'swarm') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker stack deploy -c docker-compose.yaml cyphernode
<% } else if(docker_mode == 'compose') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker-compose -f docker-compose.yaml up -d
<% } %>