#!/bin/sh

rm -f /container_monitor/lightning_ready

while [ ! -f "/container_monitor/bitcoin_ready" ]; do echo "bitcoin not ready" ; sleep 10 ; done
echo "bitcoin ready"

while [ ! -f "/container_monitor/cln-postgres_ready" ]; do echo "postgres not ready" ; sleep 10 ; done
echo "postgres ready"

mkdir -p /.lightning/plibs && cd /.lightning/plibs

export HOME=/.lightning/plibs

if [ -d "/.lightning/plugins" ]; then
  for plugin in /.lightning/plugins/*; do
    pip3 install --user -r $plugin/requirements.txt
  done
fi

#export HOME=/

<% if ( features.indexOf('tor') !== -1 && torifyables && torifyables.indexOf('tor_lightning') !== -1 ) { %>

while [ -z "${TORIP}" ]; do echo "tor not ready" ; TORIP=$(getent hosts tor | awk '{ print $1 }') ; sleep 10 ; done

echo "tor ready at IP ${TORIP}"

exec lightningd --lightning-dir=/.lightning --proxy=$TORIP:9050
<% } else { %>

exec lightningd --lightning-dir=/.lightning

<% } %>
