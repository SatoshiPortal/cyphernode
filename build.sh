#!/bin/bash

TRACING=1

# CYPHERNODE VERSION "v0.2.0"
CONF_VERSION="v0.2.0-local"
GATEKEEPER_VERSION="v0.2.0-local"
PROXY_VERSION="v0.2.0-local"
PROXYCRON_VERSION="v0.2.0-local"
OTSCLIENT_VERSION="v0.2.0-local"
PYCOIN_VERSION="v0.2.0-local"
BITCOIN_VERSION="v0.17.1"
LIGHTNING_VERSION="v0.7.0"
GRAFANA_VERSION="v0.2.0-local"

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

build_docker_images() {
  trace "Updating SatoshiPortal repos"

  trace "Creating cyphernodeconf image"
  docker build  install/ -t cyphernode/cyphernodeconf:$CONF_VERSION

  trace "Creating cyphernode images"
  docker build  api_auth_docker/ -t cyphernode/gatekeeper:$GATEKEEPER_VERSION
  docker build  proxy_docker/ -t cyphernode/proxy:$PROXY_VERSION
  docker build  cron_docker/ -t cyphernode/proxycron:$PROXYCRON_VERSION
  docker build  pycoin_docker/ -t cyphernode/pycoin:$PYCOIN_VERSION
  docker build  otsclient_docker/ -t cyphernode/otsclient:$OTSCLIENT_VERSION
}

build_docker_images
