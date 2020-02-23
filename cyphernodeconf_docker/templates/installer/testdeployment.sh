#!/bin/sh

. ./.cyphernodeconf/installer/config.sh

# be aware that randomly downloaded cyphernode apps will have access to
# your configuration and filesystem.
# !!!!!!!!! DO NOT INCLUDE APPS WITHOUT REVIEW !!!!!!!!!!
# TODO: Test if we can mitigate this security issue by
# running app dockers inside a docker container

test_apps() {
  local SCRIPT_NAME="test.sh"
  local APP_SCRIPT_PATH
  local APP_START_SCRIPT_PATH
  local APP_ID
  local returncode=0
  local TRAEFIK_HTTP_PORT=<%= traefik_http_port %>
  local TRAEFIK_HTTPS_PORT=<%= traefik_https_port %>

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
  export USER=$(id -u <%= default_username %>):$(id -g <%= default_username %>)
else
  export USER=$(id -u <%= username %>):$(id -g <%= username %>)
fi
<% } else { %>
export USER=$(id -u <%= default_username %>):$(id -g <%= default_username %>)
<% } %>

current_path="$(cd "$(dirname "$0")" >/dev/null && pwd)"

# Will test if Cyphernode is fully up and running...
docker run --rm -it -v $current_path/testfeatures.sh:/testfeatures.sh \
-v <%= gatekeeper_datapath %>:/gatekeeper \
-v $current_path:/dist \
-v cyphernode_container_monitor:/container_monitor:ro \
--network cyphernodenet eclipse-mosquitto:<%= mosquitto_version %> /testfeatures.sh

if [ -f $current_path/exitStatus.sh ]; then
  . $current_path/exitStatus.sh
  rm -f $current_path/exitStatus.sh
fi

test_apps

EXIT_STATUS=$(($? | ${EXIT_STATUS}))

printf "\r\n\e[1;32mTests finished.\e[0m\n"

if [ "$EXIT_STATUS" -ne "0" ]; then
  printf "\r\n\033[1;31mThere was an error during cyphernode installation.  full logs:  docker ps -q | xargs -L 1 docker logs , Containers logs:  docker logs <containerid> , list containers: docker ps  .Please see Docker's logs for more information.  Run ./testdeployment.sh to rerun the tests.  Run ./stop.sh to stop cyphernode.\r\n\r\n\033[0m"
  exit 1
fi

printf "\r\n\033[0;92mDepending on your current location and DNS settings, point your favorite browser to one of the following URLs to access Cyphernode's status page:\r\n"
printf "\r\n"
printf "\033[0;95m<% cns.forEach(cn => { %><%= ('https://' + cn + ':' + traefik_https_port + '/welcome\\r\\n') %><% }) %>\033[0m\r\n"
<% if ( features.indexOf('tor') !== -1 && torifyables && torifyables.indexOf('tor_traefik') !== -1 ) { %>
printf "\033[0;92mYou can also use Tor Browser and navigate to your onion address:\r\n\r\n"
printf "\033[0;95mhttps://${TOR_TRAEFIK_HOSTNAME}:<%= traefik_https_port %>/welcome\033[0m\r\n\r\n"

printf "\033[0;92mTor Browser on mobile?  We got you:\r\n\r\n\033[0m"
docker run --rm -it cyphernode/cyphernodeconf:<%= conf_version %> $USER qrencode -t UTF8 "https://${TOR_TRAEFIK_HOSTNAME}:443/welcome"
printf "\r\n"

<% } %>
printf "\033[0;92mUse 'admin' as the username with the configuration password you selected at the beginning of the configuration process.\r\n\r\n\033[0m"
