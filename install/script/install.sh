#!/bin/sh

. ./trace.sh
. ./docker.sh
. ./cyphernodeconf.sh

config_file=$1

trace "Updating SatoshiPortal dockers"
#git submodule update --recursive --remote
#
## build SatoshiPortal images
#local arch=x86_64
#build_docker_image ../SatoshiPortal/dockers/$arch/bitcoin-core btcnode
#build_docker_image ../SatoshiPortal/dockers/$arch/LN/c-lightning clnimg
#
## build cyphernode images
#build_docker_image ../../cron_docker/ proxycronimg
#build_docker_image ../../proxy_docker/ btcproxyimg
#build_docker_image ../../pycoin_docker/ pycoinimg
#
## build setup docker image
build_docker_image ../ cyphernodeconf && clear && echo "Thinking..."

# configure features of cyphernode
cyphernodeconf_configure
