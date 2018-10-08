install_docker() {

	echo 

	if [[ $BITCOIN_INTERAL == true || $FEATURE_LIGHTNING == true ]]; then
		trace "Updating SatoshiPortal repos"
	  git submodule update --recursive --remote
	fi
  
  # build SatoshiPortal images
  local arch=$(uname -m) #x86_64

  if [[ $BITCOIN_INTERNAL == true ]]; then
  	build_docker_image ../SatoshiPortal/dockers/$arch/bitcoin-core cyphernode/bitcoin
  fi

  if [[ $FEATURE_LIGHTNING == true ]]; then
  	build_docker_image ../SatoshiPortal/dockers/$arch/LN/c-lightning cyphernode/clightning
  fi

 	if [[ $FEATURE_OTSCLIENT == true ]]; then
  	build_docker_image ../SatoshiPortal/dockers/$arch/ots/otsclient cyphernode/otsclient
  fi 
  
  
  # build cyphernode images
  trace "Creating cyphernode dockers"
  build_docker_image ../../proxy_docker/ cyphernode/proxy
  build_docker_image ../../cron_docker/ cyphernode/proxycron
  build_docker_image ../../pycoin_docker/ cyphernode/pycoin

  trace "Creating cyphernode network"
  docker network create cyphernodenet > /dev/null 2>&1
}