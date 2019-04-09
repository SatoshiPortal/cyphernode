#!/bin/sh

. ./installer/config.sh

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

      if [ -f "$APP_START_SCRIPT_PATH" ]; then
        APP_ID=$(basename $APP_SCRIPT_PATH)
        . $APP_START_SCRIPT_PATH
      elif [ -f "$APP_SCRIPT_PATH/docker-compose.yaml" ]; then
        export SHARED_HTPASSWD_PATH
        export GATEKEEPER_DATAPATH
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

test_apps() {
  local SCRIPT_NAME="test.sh"
  local APP_SCRIPT_PATH
  local APP_START_SCRIPT_PATH
  local APP_ID
  local returncode=0

  for i in $current_path/apps/*
  do
    APP_SCRIPT_PATH=$(echo $i)
    if [ -d "$APP_SCRIPT_PATH" ]; then
      APP_TEST_SCRIPT_PATH="$APP_SCRIPT_PATH/$SCRIPT_NAME"

      if [ -f "$APP_TEST_SCRIPT_PATH" ] && [ ! -f "$APP_SCRIPT_PATH/ignoreThisApp" ]; then
        APP_ID=$(basename "$APP_SCRIPT_PATH")
        printf "\r\n\e[1;36mTesting $APP_ID... \e[1;0m"
        . $APP_TEST_SCRIPT_PATH
        local rc=$?

        if [ ""$rc -eq "0" ]; then
          printf "\e[1;36m$APP_ID rocks!\e[1;0m"
        fi
        returncode=$(($rc | ${returncode}))
        echo ""
      fi
    fi
  done
  return $returncode
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

arch=$(uname -m)
case "${arch}" in arm*)
  printf "\r\n\033[1;31mSince we're on a slow RPi, let's give Docker 60 more seconds before performing our tests...\033[0m\r\n\r\n"
  sleep 60
;;
esac

# Will test if Cyphernode is fully up and running...
docker run --rm -it -v $current_path/testfeatures.sh:/testfeatures.sh \
-v <%= gatekeeper_datapath %>:/gatekeeper \
-v $current_path:/dist \
--network cyphernodenet alpine:3.8 /testfeatures.sh

if [ -f $current_path/exitStatus.sh ]; then
  . $current_path/exitStatus.sh
  rm -f $current_path/exitStatus.sh
fi

test_apps

EXIT_STATUS=$(($? | ${EXIT_STATUS}))

printf "\r\n\e[1;32mTests finished.\e[0m\n"

if [ "$EXIT_STATUS" -ne "0" ]; then
  printf "\r\n\033[1;31mThere was an error during cyphernode installation.  Please see Docker's logs for more information.  Run ./stop.sh to stop cyphernode.\r\n\r\n\033[0m"
  exit 1
fi

printf "\r\n\033[0;92mDepending on your current location and DNS settings, point your favorite browser to one of the following URLs to access Cyphernode's status page:\r\n"
printf "\r\n"
printf "\033[0;95m<% cns.forEach(cn => { %><%= ('https://' + cn + '/welcome\\r\\n') %><% }) %>\033[0m\r\n"
printf "\033[0;92mUse 'admin' as the username with the configuration password you selected at the beginning of the configuration process.\r\n\r\n\033[0m"
