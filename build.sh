#!/bin/bash

TRACING=1

# CYPHERNODE VERSION "v0.6.0-dev"
CONF_VERSION="v0.6.0-dev-local"
GATEKEEPER_VERSION="v0.6.0-dev-local"
TOR_VERSION="v0.6.0-dev-local"
PROXY_VERSION="v0.6.0-dev-local"
NOTIFIER_VERSION="v0.6.0-dev-local"
PROXYCRON_VERSION="v0.6.0-dev-local"
OTSCLIENT_VERSION="v0.6.0-dev-local"
PYCOIN_VERSION="v0.6.0-dev-local"
BITCOIN_VERSION="v0.21.0"
LIGHTNING_VERSION="v0.9.1"

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
  docker build  cyphernodeconf_docker/ -t cyphernode/cyphernodeconf:$CONF_VERSION

  trace "Creating cyphernode images"
  docker build api_auth_docker/ -t cyphernode/gatekeeper:$GATEKEEPER_VERSION \
  && docker build tor_docker/ -t cyphernode/tor:$TOR_VERSION \
  && docker build proxy_docker/ -t cyphernode/proxy:$PROXY_VERSION \
  && docker build notifier_docker/ -t cyphernode/notifier:$NOTIFIER_VERSION \
  && docker build cron_docker/ -t cyphernode/proxycron:$PROXYCRON_VERSION \
  && docker build pycoin_docker/ -t cyphernode/pycoin:$PYCOIN_VERSION \
  && docker build otsclient_docker/ -t cyphernode/otsclient:$OTSCLIENT_VERSION
}

build_docker_images
