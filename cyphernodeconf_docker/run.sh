#!/bin/sh

export SETUP_DIR=$(pwd)/../dist
export DEFAULT_USER=$USER
export DEFAULT_CERT_HOSTNAME=disk0book.local
export PROXYCRON_VERSION=v0.4.0-rc.2
export PYCOIN_VERSION=v0.4.0-rc.2
export SETUP_VERSION=v0.4.0-rc.2
export BITCOIN_VERSION=v0.19.1
export LIGHTNING_VERSION=v0.8.2
export DEFAULT_DATADIR_BASE=$HOME
export GATEKEEPER_VERSION=v0.4.0-rc.2
export TOR_VERSION=v0.4.0-rc.2
export PROXY_VERSION=v0.4.0-rc.2
export OTSCLIENT_VERSION=v0.4.0-rc.2
export NOTIFIER_VERSION=v0.4.0-rc.2
export EDITOR=/usr/bin/nano
export TRAEFIK_VERSION="v1.7.9-alpine"
export MOSQUITTO_VERSION="1.6"

user=$(id -u):$(id -g)

if [ "${MODE}" = 'docker' ]; then
  docker build . -t cyphernodeconf:local
  docker run -v $(pwd)/testinst:/data \
           -e DEFAULT_USER=jash \
           -e DEFAULT_DATADIR_BASE=$HOME \
           -e SETUP_DIR=$SETUP_DIR \
           -e DEFAULT_CERT_HOSTNAME=$(hostname) \
           -e GATEKEEPER_VERSION=$GATEKEEPER_VERSION \
           -e TRAEFIK_VERSION=$TRAEFIK_VERSION \
           -e MOSQUITTO_VERSION=$MOSQUITTO_VERSION \
           -e TOR_VERSION=$TOR_VERSION \
           -e PROXY_VERSION=$PROXY_VERSION \
           -e NOTIFIER_VERSION=$NOTIFIER_VERSION \
           -e PROXYCRON_VERSION=$PROXYCRON_VERSION \
           -e OTSCLIENT_VERSION=$OTSCLIENT_VERSION \
           -e PYCOIN_VERSION=$PYCOIN_VERSION \
           -e BITCOIN_VERSION=$BITCOIN_VERSION \
           -e LIGHTNING_VERSION=$LIGHTNING_VERSION \
           -e SETUP_VERSION=$SETUP_VERSION \
           -e DEFAULT_USER=$DEFAULT_USER \
           --log-driver=none \
           --network none \
           --rm -it cyphernodeconf:local $user node index.js $@
else
  /usr/local/bin/node index.js $@
fi
