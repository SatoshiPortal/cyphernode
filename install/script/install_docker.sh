. ./docker.sh

install_docker() {

	echo 

	if [[ $BITCOIN_INTERAL == true || $FEATURE_LIGHTNING == true ]]; then
		trace "Updating SatoshiPortal repos"
	  git submodule update --recursive --remote
	  trace "Creating SatoshiPortal images"

	fi
  
  local arch=$(uname -m) # TODO: is this correct for every host

  if [[ $BITCOIN_INTERNAL == true ]]; then
  	build_docker_image ../SatoshiPortal/dockers/$arch/bitcoin-core cyphernode/bitcoin
  fi

  if [[ $FEATURE_LIGHTNING == true ]]; then
  	if [[ $LIGHTNING_IMPLEMENTATION == "c-lightning" ]]; then
  	  	build_docker_image ../SatoshiPortal/dockers/$arch/LN/c-lightning cyphernode/clightning
  	elif [[ $LIGHTNING_IMPLEMENTATION == "lnd" ]]; then
  			trace "lnd is not supported right now"
  	fi
  fi

 	if [[ $FEATURE_OTSCLIENT == true ]]; then
  	build_docker_image ../SatoshiPortal/dockers/$arch/ots/otsclient cyphernode/otsclient
  fi 
  
  
  # build cyphernode images
  trace "Creating cyphernode images"
  build_docker_image ../../proxy_docker/ cyphernode/proxy
  build_docker_image ../../cron_docker/ cyphernode/proxycron
  build_docker_image ../../pycoin_docker/ cyphernode/pycoin

  trace "Creating cyphernode network"
  docker network create cyphernodenet > /dev/null 2>&1
}