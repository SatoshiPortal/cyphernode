#!/bin/bash

TRACING=1

# CYPHERNODE VERSION "v0.9.0-dev"
CONF_VERSION="v0.9.0-dev-local"
GATEKEEPER_VERSION="v0.9.0-dev-local"
TOR_VERSION="v0.9.0-dev-local"
PROXY_VERSION="v0.9.0-dev-local"
NOTIFIER_VERSION="v0.9.0-dev-local"
PROXYCRON_VERSION="v0.9.0-dev-local"
OTSCLIENT_VERSION="v0.9.0-dev-local"
PYCOIN_VERSION="v0.9.0-dev-local"
PAYMENTALIST_VERSION="v0.9.0-dev-local"
BARKD_VERSION="v0.9.0-dev-local"
. "$(dirname "$(realpath "$0")")/dist/bitcoin-signet-version.sh"

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
  && docker build paymentalist_docker/ -t cyphernode/paymentalist:$PAYMENTALIST_VERSION \
  && docker build barkd_docker/ -t cyphernode/barkd:$BARKD_VERSION
}

build_docker_images

# Bitcoin Core for a custom signet whose block time is not 600 seconds, such
# as Cyphernet. It compiles Bitcoin Core, so it is only built on request.
if [ "${BUILD_BITCOIN_SIGNET}" = "true" ]; then
  trace "Creating the custom signet Bitcoin Core image"
  docker build bitcoin_signet_docker/ -t cyphernode/bitcoin:$BITCOIN_SIGNET_VERSION
fi
