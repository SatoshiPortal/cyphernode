#!/bin/sh

. ./.cyphernodeconf/installer/config.sh

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"
# !!!!!!!!! DO NOT INCLUDE APPS WITHOUT REVIEW !!!!!!!!!!

stop_apps() {
  local SCRIPT_NAME="stop.sh"
  local APP_SCRIPT_PATH
  local APP_START_SCRIPT_PATH
  local APP_ID

  for i in $current_path/apps/*
  do
    APP_SCRIPT_PATH=$(echo $i)
    if [ -d "$APP_SCRIPT_PATH" ]; then
      APP_STOP_SCRIPT_PATH="$APP_SCRIPT_PATH/$SCRIPT_NAME"
      APP_ID=$(basename $APP_SCRIPT_PATH)

      if [ -f "$APP_SCRIPT_PATH/docker-compose.yaml" ]; then
        export GATEKEEPER_CERT_FILE="$GATEKEEPER_DATAPATH/cert.pem"
        export CLIGHTNING_RPC_SOCKET="$LIGHTNING_DATAPATH/lightning-rpc"
        export APP_DATA="$APP_SCRIPT_PATH"
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

<% if (docker_mode == 'swarm') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker stack rm cyphernode
<% } else if(docker_mode == 'compose') { %>
export USER=$(id -u):$(id -g)
export ARCH=$(uname -m)
docker-compose -f $current_path/docker-compose.yaml down
<% } %>
