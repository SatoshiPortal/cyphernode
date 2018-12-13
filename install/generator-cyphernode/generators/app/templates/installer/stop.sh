#!/bin/sh

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"

<% if (docker_mode == 'swarm') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker stack rm cyphernode
<% } else if(docker_mode == 'compose') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker-compose -f $current_path/docker-compose.yaml down
<% } %>
