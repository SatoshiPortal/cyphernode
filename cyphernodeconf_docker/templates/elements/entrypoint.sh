#!/bin/sh

_term() { 
  echo "Caught SIGTERM signal!" 
  kill -TERM "$child" 2>/dev/null
}

trap _term SIGTERM

rm -f /container_monitor/elements_ready

while [ ! -f "/container_monitor/bitcoin_ready" ]; do echo "bitcoin not ready" ; sleep 10 ; done

echo "bitcoin ready"

<% if ( features.indexOf('tor') !== -1 && torifyables && torifyables.indexOf('tor_elements') !== -1 ) { %>
#while [ ! -f "/container_monitor/tor_ready" ]; do echo "tor not ready" ; sleep 10 ; done
while [ -z "${TORIP}" ]; do echo "tor not ready" ; TORIP=$(getent hosts tor | awk '{ print $1 }') ; sleep 10 ; done

#TORIP=$(getent hosts tor | awk '{ print $1 }')
echo "tor ready at IP ${TORIP}"

elementsd --proxy=$TORIP:9050 &
<% } else { %>

elementsd &

<% } %>

child=$!
wait "$child"
