#!/bin/bash

TRACING=1

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


build_docker_image() {

  local dockerfile="Dockerfile"

  if [[ ""$3 != "" ]]; then
    dockerfile=$3
  fi

  trace "building docker image: $2"
  #docker build -q $1 -f $1/$dockerfile -t $2:latest > /dev/null
  docker build $1 -f $1/$dockerfile -t $2

}

build_docker_images() {
  trace "Updating SatoshiPortal repos"
  git submodule update --recursive --remote

  local bitcoin_dockerfile=Dockerfile.amd64
  local clightning_dockerfile=Dockerfile.amd64
  local proxy_dockerfile=Dockerfile.amd64

  # compat mode for SatoshiPortal repo
  # TODO: add more mappings?
  if [[ $(uname -m) == 'armv7l' ]]; then
    bitcoin_dockerfile="Dockerfile.arm32v6"
    clightning_dockerfile="Dockerfile.arm32v6"
    proxy_dockerfile="Dockerfile.arm32v6"
  fi

  trace "Creating cyphernodeconf image"
  build_docker_image install/ cyphernode/cyphernodeconf:$CN_VERSION

  trace "Creating SatoshiPortal images"
  build_docker_image install/SatoshiPortal/dockers/bitcoin-core cyphernode/bitcoin:$BC_VERSION $bitcoin_dockerfile
  build_docker_image install/SatoshiPortal/dockers/c-lightning cyphernode/clightning:$CL_VERSION $clightning_dockerfile

  trace "Creating cyphernode images"
  build_docker_image api_auth_docker/ cyphernode/gatekeeper:$CN_VERSION
  build_docker_image proxy_docker/ cyphernode/proxy:$CN_VERSION $proxy_dockerfile
  build_docker_image cron_docker/ cyphernode/proxycron:$CN_VERSION
  build_docker_image pycoin_docker/ cyphernode/pycoin:$CN_VERSION
  build_docker_image otsclient_docker/ cyphernode/otsclient:$CN_VERSION
  build_docker_image grafana_docker/ cyphernode/grafana:$CN_VERSION

}

# CYPHERNODE VERSION
GATEKEEPER_VERSION="latest"
PROXY_VERSION="latest"
PROXYCRON_VERSION="latest"
OTSCLIENT_VERSION="latest"
PYCOIN_VERSION="latest"
BITCOIN_VERSION="latest"
LIGHTNING_VERSION="latest"

build_docker_images
