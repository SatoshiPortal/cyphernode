#!/bin/bash

### Execute this on a freshly install ubuntu luna node
# curl -fsSL get.docker.com -o get-docker.sh
# sh get-docker.sh
# sudo usermod -aG docker $USER
## >>logout and relogin<<
# git clone --branch features/install --recursive https://github.com/schulterklopfer/cyphernode.git
# sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# sudo chmod +x /usr/local/bin/docker-compose
# cd cyphernode
# ./setup.sh -ci
# docker-compose -f docker-compose.yaml up [-d]

trace()
{
  if [ -n "${TRACING}" ]; then
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] ${1}" > /dev/stderr
  fi
}

trace_rc()
{
  if [ -n "${TRACING}" ]; then
    echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] Last return code: ${1}" > /dev/stderr
  fi
}

configure() {
  local current_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
  ## build setup docker image
  local recreate=""

  if [[ $1 == 1 ]]; then
    recreate="recreate"
  fi

  clear && echo "Thinking..."

  # configure features of cyphernode
  docker run -v $current_path:/data \
             --log-driver=none\
             --rm -it cyphernodeconf:latest $(id -u):$(id -g) yo --no-insight cyphernode $recreate
  
}

install_docker() {

  local sourceDataPath=./
  local topLevel=./

  if [[ $BITCOIN_INTERNAL == true ]]; then
    if [ ! -d $BITCOIN_DATAPATH ]; then
      trace "Creating $BITCOIN_DATAPATH"
      mkdir -p $BITCOIN_DATAPATH
    fi

    if [[ -f $BITCOIN_DATAPATH/bitcoin.conf ]]; then
      trace "Creating backup of $BITCOIN_DATAPATH/bitcoin.conf"
      cp $BITCOIN_DATAPATH/bitcoin.conf $BITCOIN_DATAPATH/bitcoin.conf-$(date +"%y-%m-%d-%T")
    fi

    trace "Copying bitcoin core node config"
    cp $sourceDataPath/bitcoin/bitcoin.conf $BITCOIN_DATAPATH
  fi

  if [[ $FEATURE_LIGHTNING == true ]]; then
    if [[ $LIGHTNING_IMPLEMENTATION == "c-lightning" ]]; then
        local dockerfile="Dockerfile"
        if [[ $archpath == "rpi" ]]; then
          dockerfile="Dockerfile-alpine"
        fi
        if [ ! -d $LIGHTNING_DATAPATH ]; then
          trace "Creating $LIGHTNING_DATAPATH"
          mkdir -p $LIGHTNING_DATAPATH
        fi

        if [[ -f $LIGHTNING_DATAPATH/config ]]; then
          trace "Creating backup of $LIGHTNING_DATAPATH/config"
          cp $LIGHTNING_DATAPATH/config $LIGHTNING_DATAPATH/config-$(date +"%y-%m-%d-%T")
        fi

        trace "Copying c-lightning config"
        cp $sourceDataPath/lightning/c-lightning/config $LIGHTNING_DATAPATH
    fi
  fi

  if [[ $FEATURE_OTSCLIENT == true ]]; then
    trace "opentimestamps not supported yet."
  fi 
  
  # build cyphernode images
  if [ ! -d $PROXY_DATAPATH ]; then
    trace "Creating $PROXY_DATAPATH"
    mkdir -p $PROXY_DATAPATH
  fi
  trace "Creating cyphernode network"
  docker network create cyphernodenet > /dev/null 2>&1

  if [[ -f $topLevel/docker-compose.yaml ]]; then
    trace "Creating backup of docker-compose.yaml"
    cp $topLevel/docker-compose.yaml $topLevel/docker-compose.yaml-$(date +"%y-%m-%d-%T")
  fi

  trace "Copying docker-compose.yaml to top level"
  cp $sourceDataPath/installer/docker/docker-compose.yaml $topLevel/docker-compose.yaml

  echo "+---------------------------------------------------------------+"
  echo "|                     to start cyphernode run:                  |"
  echo '| USER=`id -u`:`id -g` docker-compose -f docker-compose.yaml up |'
  echo "+---------------------------------------------------------------+"

}

install() {
  . installer/config.sh
  if [[ ''$INSTALLER_MODE == 'none' ]]; then
    echo "Skipping installation phase"
  elif [[ ''$INSTALLER_MODE == 'docker' ]]; then
    install_docker
  fi
}


CONFIGURE=0
INSTALL=0
RECREATE=0
TRACING=1

while getopts ":cir" opt; do
  case $opt in
    r)
      RECREATE=1
      ;;
    c)
      CONFIGURE=1
      ;;
    i)
      INSTALL=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG. Use -c to configure and -i to install" >&2
      ;;
  esac
done

if [[  $CONFIGURE == 0 && $INSTALL == 0 && RECREATE == 0 ]]; then
    echo "Please use -c to configure, -i to install and -ci to do both. Use -r to recreate config files."
else
  if [[ $CONFIGURE == 1 ]]; then
    trace "Starting configuration phase"
    configure $RECREATE
  fi

  if [[ $INSTALL == 1 ]]; then
    trace "Starting installation phase"
    install
  fi
fi

