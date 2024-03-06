#!/bin/bash

DIR="$( dirname -- "${BASH_SOURCE[0]}"; )";
. $DIR/colors.sh
. $DIR/mine.sh

# This needs to be run in regtest
# You need jq installed for these tests to run correctly

# This will test the missed watched transactions mechanisms by broadcasting
# transactions on watched addresses while the proxy is shut down...
#
# - getnewaddress
# - watch
# - executecallbacks
#

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

create_cb_server() {
  trace 1 "\n\n[create_cb_server] ${BCyan}Creating cb-server.sh...${Color_Off}\n"

  local cbserver_b64
  cbserver_b64=$(echo '#!/bin/sh

lookingfor=$1
returncode=0

a=$(timeout 1 tee)

echo -en "\033[40m\033[0;37m" >&2
date >&2
echo "$a" >&2

case "$a" in
  *$lookingfor*)
    echo -e "\033[42m\033[0;30m  Found \"$lookingfor\" in request!  \033[40m" >&2
    found=true
    ;;
esac

echo -e "\033[0m" >&2

if [ "$found" = "true" ]; then
  echo -en "HTTP/1.1 200 OK\r\n\r\n"
else
  echo -en "HTTP/1.1 404 NOT FOUND\r\n\r\n"
  returncode=1
fi
echo -en "$a"

return ${returncode}
' | base64)

  local execcmd
  execcmd="echo \"${cbserver_b64}\" | base64 -d > cb-server.sh && chmod +x cb-server.sh"
  exec_in_test_container sh -c "$execcmd"

  trace 1 "\n\n[create_cb_server] ${BCyan}Created cb-server.sh...${Color_Off}\n"
}

start_test_container() {
  docker run -d --rm -t --name tests-manage-missed --network=cyphernodenet alpine:3.15.4
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop tests-manage-missed
  local containers=$(docker ps -q -f "name=tests-manage-missed")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec -it tests-manage-missed "$@"
}

exec_in_test_container_nonint() {
  docker exec -t tests-manage-missed "$@"
}

wait_for_proxy() {
  trace 1 "\n\n[wait_for_proxy] ${BCyan}Waiting for the proxy to be ready...${Color_Off}\n"

  # First ping the containers to make sure they're up...
  docker exec -t tests-manage-missed sh -c 'while true ; do ping -c 1 proxy ; [ "$?" -eq "0" ] && break ; sleep 5; done'

  # Now check if it's ready to accecpt requests
  docker exec -t tests-manage-missed sh -c 'while true ; do curl proxy:8888/helloworld > /dev/null; [ "$?" -eq "0" ] && break ; sleep 5; done'
}

wait_for_broker() {
  trace 1 "\n\n[wait_for_broker] ${BCyan}Waiting for the broker to be ready...${Color_Off}\n"

  # First ping the containers to make sure they're up...
  docker exec -t tests-manage-missed sh -c 'while true ; do ping -c 1 broker ; [ "$?" -eq "0" ] && break ; sleep 5; done'
}

test_manage_missed_0_conf() {
  # Missed 0-conf:
  # 1. Get new address
  # 2. Watch it
  # 3. Stop proxy
  # 4. sendtoaddress while proxy is offline
  # 5. Start proxy
  # 6. Call executecallbacks
  # 7. Check if 0-conf callback is called
  # 8. Mine a block
  # 9. Check if 1-conf callback is called

  local id0=$RANDOM
  local id1=$RANDOM

  local port0=${id0}
  local port1=${id1}

  local callbackurl0conf="http://${callbackservername}:${port0}/callbackurl0conf"
  local callbackurl1conf="http://${callbackservername}:${port1}/callbackurl1conf"

  trace 1 "\n[test_manage_missed_0_conf] ${BCyan}Let's miss a 0-conf!...${Color_Off}"

  trace 2 "[test_manage_missed_0_conf] getnewaddress..."
  local response=$(exec_in_test_container curl -d '{"label":"missed0conftest"}' proxy:8888/getnewaddress)
  trace 3 "[test_manage_missed_0_conf] response=${response}"
  local address=$(echo "${response}" | jq -r ".address")
  trace 3 "[test_manage_missed_0_conf] address=${address}"

  start_callback_server $port0 ${address} &
  start_callback_server $port1 ${address} &

  trace 2 "[test_manage_missed_0_conf] watch it..."
  local data='{"address":"'${address}'","unconfirmedCallbackURL":"'${callbackurl0conf}'","confirmedCallbackURL":"'${callbackurl1conf}'","label":"missed0conftest"}'
  trace 3 "[test_manage_missed_0_conf] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
  trace 3 "[test_manage_missed_0_conf] response=${response}"

  trace 3 "[test_manage_missed_0_conf] Shutting down the proxy..."
  # There are two container names containing "proxy": proxy and proxycron
  # Let's exclude proxycron
  docker stop $(docker ps -q -f "name=proxy[^c]")

  trace 3 "[test_manage_missed_0_conf] Sending coins to watched address while proxy is down..."
  docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address} 0.0001

  wait_for_proxy

  trace 3 "[test_manage_missed_0_conf] Calling executecallbacks..."
  exec_in_test_container curl -s -H "Content-Type: application/json" proxy:8888/executecallbacks

  # 1 conf callback should be called after this
  mine

  # wait for callback servers
  trace 3 "[test_manage_missed_0_conf] Waiting for callbacks..."

  wait
  trace 3 "[test_manage_missed_0_conf] ${On_IGreen}${BBlack} Done - Waiting for callbacks...${Color_Off}"
}

test_manage_missed_1_conf() {
  # Missed 1-conf:
  # 1. Get new address
  # 2. Watch it
  # 3. sendtoaddress
  # 4. Check if 0-conf callback is called
  # 5. Stop proxy
  # 6. Mine a new block
  # 7. Start proxy
  # 8. Call executecallbacks
  # 9. Check if 1-conf callback is called

  local id0=$RANDOM
  local id1=$RANDOM

  local port0=${id0}
  local port1=${id1}

  local callbackurl0conf="http://${callbackservername}:${port0}/callbackurl0conf"
  local callbackurl1conf="http://${callbackservername}:${port1}/callbackurl1conf"

  trace 1 "\n[test_manage_missed_1_conf] ${BCyan}Let's miss a 1-conf!...${Color_Off}"

  trace 2 "[test_manage_missed_1_conf] getnewaddress..."
  local response=$(exec_in_test_container curl -d '{"label":"missed0conftest"}' proxy:8888/getnewaddress)
  trace 3 "[test_manage_missed_1_conf] response=${response}"
  local address=$(echo "${response}" | jq -r ".address")
  trace 3 "[test_manage_missed_1_conf] address=${address}"

  start_callback_server $port0 ${address} &
  start_callback_server $port1 ${address} &

  trace 2 "[test_manage_missed_1_conf] watch it..."
  local data='{"address":"'${address}'","unconfirmedCallbackURL":"'${callbackurl0conf}'","confirmedCallbackURL":"'${callbackurl1conf}'","label":"missed1conftest"}'
  trace 3 "[test_manage_missed_1_conf] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
  trace 3 "[test_manage_missed_1_conf] response=${response}"

  trace 3 "[test_manage_missed_1_conf] Sending coins to watched address while proxy is up..."
  docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address} 0.0001

  trace 3 "[test_manage_missed_1_conf] Sleeping for 20 seconds to let the 0-conf callbacks to happen..."
  sleep 20

  trace 3 "[test_manage_missed_1_conf] Shutting down the proxy..."
  # There are two container names containing "proxy": proxy and proxycron
  # Let's exclude proxycron
  docker stop $(docker ps -q -f "name=proxy[^c]")

  trace 3 "[test_manage_missed_1_conf] Mine a new block..."
  mine

  wait_for_proxy

  trace 3 "[test_manage_missed_1_conf] Calling executecallbacks..."
  exec_in_test_container curl -s -H "Content-Type: application/json" proxy:8888/executecallbacks

  # wait for callback servers
  trace 3 "[test_manage_missed_1_conf] Waiting for callbacks..."

  wait
  trace 3 "[test_manage_missed_1_conf] ${On_IGreen}${BBlack} Done - Waiting for callbacks...${Color_Off}"
}

test_manage_missed_1_conf_dead_broker() {
  # Missed 1-conf:
  # 1. Get new address
  # 2. Watch it
  # 3. sendtoaddress
  # 4. Check if 0-conf callback is called
  # 5. Stop broker
  # 6. Mine a new block
  # 7. Wait for broker
  # 8. Call executecallbacks
  # 9. Check if 1-conf callback is called

  trace 1 "\n[test_manage_missed_1_conf_dead_broker] ${BCyan}Let's miss a 1-conf with a dead broker!...${Color_Off}"

  local id0=$RANDOM
  local id1=$RANDOM

  local port0=${id0}
  local port1=${id1}

  local callbackurl0conf="http://${callbackservername}:${port0}/callbackurl0conf"
  local callbackurl1conf="http://${callbackservername}:${port1}/callbackurl1conf"

  trace 2 "[test_manage_missed_1_conf_dead_broker] getnewaddress..."
  local response=$(exec_in_test_container curl -d '{"label":"missed0conftest"}' proxy:8888/getnewaddress)
  trace 3 "[test_manage_missed_1_conf_dead_broker] response=${response}"
  local address=$(echo "${response}" | jq -r ".address")
  trace 3 "[test_manage_missed_1_conf_dead_broker] address=${address}"

  start_callback_server $port0 ${address} &
  start_callback_server $port1 ${address} &

  trace 2 "[test_manage_missed_1_conf_dead_broker] watch it..."
  local data='{"address":"'${address}'","unconfirmedCallbackURL":"'${callbackurl0conf}'","confirmedCallbackURL":"'${callbackurl1conf}'","label":"missed0conftest"}'
  trace 3 "[test_manage_missed_1_conf_dead_broker] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
  trace 3 "[test_manage_missed_1_conf_dead_broker] response=${response}"

  trace 3 "[test_manage_missed_1_conf_dead_broker] Sending coins to watched address while proxy is up..."
  docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address} 0.0001

  trace 3 "[test_manage_missed_1_conf_dead_broker] Sleeping for 20 seconds to let the 0-conf callbacks to happen..."
  sleep 20

  trace 3 "[test_manage_missed_1_conf_dead_broker] Shutting down the broker..."
  docker stop $(docker ps -q -f "name=broker")

  trace 3 "[test_manage_missed_1_conf_dead_broker] Mine a new block..."
  mine

  wait_for_broker

  trace 3 "[test_manage_missed_1_conf_dead_broker] Calling executecallbacks..."
  exec_in_test_container curl -s -H "Content-Type: application/json" proxy:8888/executecallbacks

  # wait for callback servers
  trace 3 "[test_manage_missed_1_conf] Waiting for callbacks..."

  wait
  trace 3 "[test_manage_missed_1_conf] ${On_IGreen}${BBlack} Done - Waiting for callbacks...${Color_Off}"
}

start_callback_server() {
  trace 1 "\n\n[start_callback_server] ${BCyan}Let's start a callback server!...${Color_Off}\n"

  local port expected_text
  port=${1:-${callbackserverport}}
  expected_text=$2

  exec_in_test_container_nonint sh -c 'nc -vlp'${port}' -e ./cb-server.sh '${expected_text}' ; echo "::$?::"'
}

TRACING=3

stop_test_container
start_test_container

exec_in_test_container apk add --update curl

create_cb_server
callbackservername="tests-manage-missed"

test_manage_missed_0_conf
test_manage_missed_1_conf
test_manage_missed_1_conf_dead_broker

stop_test_container
