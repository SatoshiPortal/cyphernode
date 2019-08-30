#!/bin/bash

TRACING=1

# CYPHERNODE VERSION "v0.4.0"
CONF_VERSION="v0.4.0-local"
GATEKEEPER_VERSION="v0.4.0-local"
TOR_VERSION="v0.4.0-local"
PROXY_VERSION="v0.4.0-local"
NOTIFIER_VERSION="v0.4.0-local"
PROXYCRON_VERSION="v0.4.0-local"
OTSCLIENT_VERSION="v0.4.0-local"
PYCOIN_VERSION="v0.4.0-local"
BITCOIN_VERSION="v0.19.1"
LIGHTNING_VERSION="v0.8.2"
WASABI_VERSION="v0.3.1-local"

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
  && docker build otsclient_docker/ -t cyphernode/otsclient:$OTSCLIENT_VERSION \
  && docker build wasabi_docker/ -t cyphernode/wasabi:$WASABI_VERSION \
  && docker build wasabi_docker/backend -t cyphernode/wasabi-backend:$WASABI_VERSION
}

build_docker_images
