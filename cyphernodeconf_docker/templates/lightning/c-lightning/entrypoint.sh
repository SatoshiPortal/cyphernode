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
    if [ -f "$plugin/requirements.txt" ]; then
      if ! command -v pip3 >/dev/null 2>&1; then
        echo "Python plugin requirements need pip3; the official CLN image does not include it" >&2
        exit 1
      fi
      pip3 install --user -r "$plugin/requirements.txt" || exit 1
    fi
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
