. ./docker.sh

install_docker() {

  local sourceDataPath=../data
  local topLevel=../..

  if [[ $BITCOIN_INTERNAL == true || $FEATURE_LIGHTNING == true ]]; then
    trace "Updating SatoshiPortal repos"
    git submodule update --recursive --remote
    trace "Creating SatoshiPortal images"

  fi

  local archpath=$(uname -m)

  # compat mode for SatoshiPortal repo
  # TODO: add more mappings?
  if [[ $archpath == 'armv7l' ]]; then
    archpath="rpi"
  fi

  if [[ $BITCOIN_INTERNAL == true ]]; then
    build_docker_image ../SatoshiPortal/dockers/$archpath/bitcoin-core cyphernode/bitcoin
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
        build_docker_image ../SatoshiPortal/dockers/$archpath/LN/c-lightning cyphernode/clightning
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
    build_docker_image ../SatoshiPortal/dockers/$archpath/ots/otsclient cyphernode/otsclient
  fi 
  
  
  # build cyphernode images
  trace "Creating cyphernode images"
  build_docker_image ../../proxy_docker/ cyphernode/proxy
  if [ ! -d $PROXY_DATAPATH ]; then
    trace "Creating $PROXY_DATAPATH"
    mkdir -p $PROXY_DATAPATH
  fi
  build_docker_image ../../cron_docker/ cyphernode/proxycron
  build_docker_image ../../pycoin_docker/ cyphernode/pycoin

  trace "Creating cyphernode network"
  docker network create cyphernodenet > /dev/null 2>&1

  if [[ -f $topLevel/docker-compose.yaml ]]; then
    trace "Creating backup of docker-compose.yaml"
    cp $topLevel/docker-compose.yaml $topLevel/docker-compose.yaml-$(date +"%y-%m-%d-%T")
  fi

  trace "Copying docker-compose.yaml to top level"
  cp $sourceDataPath/installer/docker/docker-compose.yaml $topLevel/docker-compose.yaml

  echo "+------------------------------------------+"
  echo "|        to start cyphernode run:          |"
  echo "| docker-compose -f docker-compose.yaml up |"
  echo "+------------------------------------------+"

}