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
    if [ -d "$APP_SCRIPT_PATH" ] && [ ! -f "$APP_SCRIPT_PATH/ignoreThisApp" ]; then
      APP_STOP_SCRIPT_PATH="$APP_SCRIPT_PATH/$SCRIPT_NAME"
      APP_ID=$(basename $APP_SCRIPT_PATH)

      if [ -f "$APP_STOP_SCRIPT_PATH" ]; then
        . $APP_STOP_SCRIPT_PATH
      elif [ -f "$APP_SCRIPT_PATH/docker-compose.yaml" ]; then
        export SHARED_HTPASSWD_PATH
        export GATEKEEPER_DATAPATH
        export GATEKEEPER_PORT
        export TOR_DATAPATH
        export LIGHTNING_DATAPATH
        export BITCOIN_DATAPATH
        export APP_SCRIPT_PATH
        export APP_ID
        export DOCKER_MODE

        if [ "$DOCKER_MODE" = "swarm" ]; then
          docker stack rm $APP_ID
        elif [ "$DOCKER_MODE" = "compose" ]; then
          docker-compose -f $APP_SCRIPT_PATH/docker-compose.yaml down
        fi

      fi
    fi
  done
}

. ./.cyphernodeconf/installer/config.sh
stop_apps

export USER=$(id -u):$(id -g)

<% if (docker_mode == 'swarm') { %>
docker stack rm cyphernode
<% } else if(docker_mode == 'compose') { %>
docker-compose -f $current_path/docker-compose.yaml down
<% } %>
