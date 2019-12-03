#!/bin/sh

. ./.cyphernodeconf/installer/config.sh

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"
# !!!!!!!!! DO NOT INCLUDE APPS WITHOUT REVIEW !!!!!!!!!!

start_apps() {
  local SCRIPT_NAME="start.sh"
  local APP_SCRIPT_PATH
  local APP_START_SCRIPT_PATH
  local APP_ID

  for i in $current_path/apps/*
  do
    APP_SCRIPT_PATH=$(echo $i)
    if [ -d "$APP_SCRIPT_PATH" ]; then
      APP_START_SCRIPT_PATH="$APP_SCRIPT_PATH/$SCRIPT_NAME"
      APP_ID=$(basename $APP_SCRIPT_PATH)

      if [ -f "$APP_SCRIPT_PATH/docker-compose.yaml" ]; then
        export GATEKEEPER_CERTS_PATH="$GATEKEEPER_DATAPATH/certs"
        export UNSAFE__CLIGHTNING_PATH="$LIGHTNING_DATAPATH"
        export APP_DATA="$APP_SCRIPT_PATH"
        export DOCKER_MODE
        export GATEKEEPER_URL="https://gatekeeper:${GATEKEEPER_PORT}"

        if [ "$DOCKER_MODE" = "swarm" ]; then
          docker stack deploy -c $APP_SCRIPT_PATH/docker-compose.yaml $APP_ID
        elif [ "$DOCKER_MODE" = "compose" ]; then
          docker-compose -f $APP_SCRIPT_PATH/docker-compose.yaml up -d --remove-orphans
        fi
      fi
    fi
  done
}

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

start_apps

. ./testdeployment.sh
