#!/bin/sh

<% if (docker_mode == 'swarm') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker stack rm cyphernode
<% } else if(docker_mode == 'compose') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker-compose -f docker-compose.yaml down
<% } %>