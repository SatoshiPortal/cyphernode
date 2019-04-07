#!/bin/sh

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"


# be aware that randomly downloaded cyphernode apps will have access to
# your configuration and filesystem.
# !!!!!!!!! DO NOT INCLUDE APPS WITHOUT REVIEW !!!!!!!!!!
# TODO: Test if we can mitigate this security issue by
# running app dockers inside a docker container

stop_apps() {
  local SCRIPT_NAME="stop.sh"
  local APP_SCRIPT_PATH
  local APP_START_SCRIPT_PATH
  local APP_ID

  for i in $current_path/apps/*
  do
    APP_SCRIPT_PATH=$(echo $i)
    if [ -d $APP_SCRIPT_PATH ]; then
      APP_START_SCRIPT_PATH="$APP_SCRIPT_PATH/$SCRIPT_NAME"

      if [ -f $APP_START_SCRIPT_PATH ]; then
        APP_ID=$(basename $APP_SCRIPT_PATH)
        . $APP_START_SCRIPT_PATH
      fi
    fi
  done
}

. ./installer/config.sh
stop_apps

<% if (docker_mode == 'swarm') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker stack rm cyphernode
<% } else if(docker_mode == 'compose') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker-compose -f $current_path/docker-compose.yaml down
<% } %>
