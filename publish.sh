#!/bin/sh

ARCH=$(uname -m)

docker tag cyphernodeconf registry.skp.rocks:5000/$ARCH/cyphernodeconf
docker tag cyphernode/bitcoin registry.skp.rocks:5000/$ARCH/cyphernode/bitcoin
docker tag cyphernode/clightning registry.skp.rocks:5000/$ARCH/cyphernode/clightning
docker tag cyphernode/otsclient registry.skp.rocks:5000/$ARCH/cyphernode/otsclient
docker tag cyphernode/proxy registry.skp.rocks:5000/$ARCH/cyphernode/proxy
docker tag cyphernode/proxycron registry.skp.rocks:5000/$ARCH/cyphernode/proxycron
docker tag cyphernode/pycoin registry.skp.rocks:5000/$ARCH/cyphernode/pycoin

docker push registry.skp.rocks:5000/$ARCH/cyphernodeconf
docker push registry.skp.rocks:5000/$ARCH/cyphernode/bitcoin
docker push registry.skp.rocks:5000/$ARCH/cyphernode/clightning
docker push registry.skp.rocks:5000/$ARCH/cyphernode/otsclient
docker push registry.skp.rocks:5000/$ARCH/cyphernode/proxy
docker push registry.skp.rocks:5000/$ARCH/cyphernode/proxycron
docker push registry.skp.rocks:5000/$ARCH/cyphernode/pycoin
