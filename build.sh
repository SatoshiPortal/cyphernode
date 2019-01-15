#!/bin/bash

TRACING=1

# CYPHERNODE VERSION "v0.1.1"
CONF_VERSION="v0.1.1-local"
GATEKEEPER_VERSION="v0.1.1-local"
PROXY_VERSION="v0.1.1-local"
PROXYCRON_VERSION="v0.1.1-local"
OTSCLIENT_VERSION="v0.1.1-local"
PYCOIN_VERSION="v0.1.1-local"
BITCOIN_VERSION="v0.17.0"
LIGHTNING_VERSION="v0.6.2"
GRAFANA_VERSION="v0.1.1-local"

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
#  git submodule update --recursive --remote

  local bitcoin_dockerfile=Dockerfile.amd64
  local clightning_dockerfile=Dockerfile.amd64
  local proxy_dockerfile=Dockerfile.amd64
  local grafana_dockerfile=Dockerfile.amd64

  # compat mode for SatoshiPortal repo
  # TODO: add more mappings?
  if [[ $(uname -m) == 'armv7l' ]]; then
    bitcoin_dockerfile="Dockerfile.arm32v6"
    clightning_dockerfile="Dockerfile.arm32v6"
    proxy_dockerfile="Dockerfile.arm32v6"
    grafana_dockerfile="Dockerfile.arm32v6"
  fi

  trace "Creating cyphernodeconf image"
  build_docker_image install/ cyphernode/cyphernodeconf:$CONF_VERSION

  trace "Creating SatoshiPortal images"
#  build_docker_image install/SatoshiPortal/dockers/bitcoin-core cyphernode/bitcoin:$BITCOIN_VERSION $bitcoin_dockerfile
#  build_docker_image install/SatoshiPortal/dockers/c-lightning cyphernode/clightning:$LIGHTNING_VERSION $clightning_dockerfile

  trace "Creating cyphernode images"
  build_docker_image api_auth_docker/ cyphernode/gatekeeper:$GATEKEEPER_VERSION
  build_docker_image proxy_docker/ cyphernode/proxy:$PROXY_VERSION $proxy_dockerfile
  build_docker_image cron_docker/ cyphernode/proxycron:$PROXYCRON_VERSION
  build_docker_image pycoin_docker/ cyphernode/pycoin:$PYCOIN_VERSION
  build_docker_image otsclient_docker/ cyphernode/otsclient:$OTSCLIENT_VERSION

}

build_docker_images
