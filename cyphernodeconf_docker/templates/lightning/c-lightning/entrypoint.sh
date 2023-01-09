#!/bin/sh

rm -f /container_monitor/lightning_ready

while [ ! -f "/container_monitor/bitcoin_ready" ]; do echo "bitcoin not ready" ; sleep 10 ; done

echo "bitcoin ready"

mkdir -p /.lightning/plibs && cd /.lightning/plibs

if [ -d "/.lightning/plugins" ]; then
  export HOME=/.lightning/plibs
  for plugin in /.lightning/plugins/*; do
    pip3 install --user -r $plugin/requirements.txt
  done
fi

export HOME=/

<% if ( features.indexOf('tor') !== -1 && torifyables && torifyables.indexOf('tor_lightning') !== -1 ) { %>

while [ -z "${TORIP}" ]; do echo "tor not ready" ; TORIP=$(getent hosts tor | awk '{ print $1 }') ; sleep 10 ; done

echo "tor ready at IP ${TORIP}"

exec lightningd --proxy=$TORIP:9050
<% } else { %>

exec lightningd

<% } %>
