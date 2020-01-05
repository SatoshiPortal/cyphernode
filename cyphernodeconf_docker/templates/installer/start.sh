#!/bin/sh

. ./.cyphernodeconf/installer/config.sh

# be aware that randomly downloaded cyphernode apps will have access to
# your configuration and filesystem.
# !!!!!!!!! DO NOT INCLUDE APPS WITHOUT REVIEW !!!!!!!!!!
# TODO: Test if we can mitigate this security issue by
# running app dockers inside a docker container

start_apps() {
  local SCRIPT_NAME="start.sh"
  local APP_SCRIPT_PATH
  local APP_START_SCRIPT_PATH
  local APP_ID

  for i in $current_path/apps/*
  do
    APP_SCRIPT_PATH=$(echo $i)
    if [ -d "$APP_SCRIPT_PATH" ] && [ ! -f "$APP_SCRIPT_PATH/ignoreThisApp" ]; then
      APP_START_SCRIPT_PATH="$APP_SCRIPT_PATH/$SCRIPT_NAME"
      APP_ID=$(basename $APP_SCRIPT_PATH)

      if [ -f "$APP_START_SCRIPT_PATH" ]; then
        . $APP_START_SCRIPT_PATH
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
