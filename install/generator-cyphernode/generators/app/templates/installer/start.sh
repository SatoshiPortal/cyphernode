#!/bin/sh

# run as user <%= username %>
export USER=$(id -u <%= run_as_different_user?username:'' %>):$(id -g <%= run_as_different_user?username:'' %>)
export ARCH=$(uname -m)

<% if (docker_mode == 'swarm') { %>
docker stack deploy -c docker-compose.yaml cyphernode
<% } else if(docker_mode == 'compose') { %>
docker-compose -f docker-compose.yaml up -d --remove-orphans
<% } %>