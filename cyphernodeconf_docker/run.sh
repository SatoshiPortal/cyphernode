#!/bin/sh

SETUP_DIR=$(pwd)/../dist
DEFAULT_CERT_HOSTNAME=disk0book.local
PROXYCRON_VERSION=v0.2.1-rc.1
PYCOIN_VERSION=v0.2.1-rc.1
SETUP_VERSION=v0.2.1-rc.1
BITCOIN_VERSION=v0.17.1
LIGHTNING_VERSION=v0.7.0
DEFAULT_DATADIR_BASE=$HOME
GATEKEEPER_VERSION=v0.2.1-rc.1
PROXY_VERSION=v0.2.1-rc.1
OTSCLIENT_VERSION=v0.2.1-rc.1
NOTIFIER_VERSION=v0.2.1-rc.1
EDITOR=/usr/bin/nano

user=$(id -u):$(id -g)

docker run -v $(pwd)/testinst:/data \
             -e DEFAULT_USER=jash \
             -e DEFAULT_DATADIR_BASE=$HOME \
             -e SETUP_DIR=$SETUP_DIR \
             -e DEFAULT_CERT_HOSTNAME=$(hostname) \
             -e GATEKEEPER_VERSION=$GATEKEEPER_VERSION \
             -e PROXY_VERSION=$PROXY_VERSION \
             -e NOTIFIER_VERSION=$NOTIFIER_VERSION \
             -e PROXYCRON_VERSION=$PROXYCRON_VERSION \
             -e OTSCLIENT_VERSION=$OTSCLIENT_VERSION \
             -e PYCOIN_VERSION=$PYCOIN_VERSION \
             -e BITCOIN_VERSION=$BITCOIN_VERSION \
             -e LIGHTNING_VERSION=$LIGHTNING_VERSION \
             -e SETUP_VERSION=$SETUP_VERSION \
             --log-driver=none \
             --network none \
             --rm -it cyphernode/cyphernodeconf:v0.2.0-local $user node index.js $@
