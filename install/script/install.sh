#!/bin/sh

. ./trace.sh
. ./docker.sh
. ./cyphernodeconf.sh

trace "Updating SatoshiPortal dockers"
git submodule update --recursive --remote

# build SatoshiPortal images
arch=x86_64
build_docker_image ../SatoshiPortal/dockers/$arch/bitcoin-core btcnode
build_docker_image ../SatoshiPortal/dockers/$arch/LN/c-lightning clnimg

# build cyphernode images
build_docker_image ../../cron_docker/ proxycronimg
build_docker_image ../../proxy_docker/ btcproxyimg
build_docker_image ../../pycoin_docker/ pycoinimg

# build setup docker image
build_docker_image ../ cyphernodeconf

# configure bitcoind
cyphernodeconf_configure bitcoind