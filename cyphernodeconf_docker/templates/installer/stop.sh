#!/bin/sh

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"
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

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"

export PWD=${current_path}

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
      export APP_ID
      export APP_DATAPATH=${APP_SCRIPT_PATH}
      export GATEKEEPER_CERTS_DATAPATH="${GATEKEEPER_DATAPATH}/certs"
      export GATEKEEPER_PORT
      export DOCKER_MODE
      export BITCOIN_NETWORK=<%= net %>
      export OTSCLIENT_DATAPATH
      export TRUSTED__LIGHTNING_DATAPATH=${LIGHTNING_DATAPATH}
      export SERVICE__LOGS_DATAPATH=${LOGS_DATAPATH}
      export SERVICE__BITCOIN_DATAPATH=${BITCOIN_DATAPATH}
      export SERVICE__TOR_DATAPATH=${TOR_DATAPATH}

      if [ -f "$APP_STOP_SCRIPT_PATH" ]; then
        . $APP_STOP_SCRIPT_PATH
      elif [ -f "$APP_SCRIPT_PATH/docker-compose.yaml" ]; then
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
