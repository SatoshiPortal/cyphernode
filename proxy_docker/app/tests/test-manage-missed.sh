#!/bin/bash

. ./colors.sh
. ./mine.sh

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

start_test_container() {
  docker run -d --rm -t --name tests-manage-missed --network=cyphernodenet alpine
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
  docker exec -it tests-manage-missed $@
}

wait_for_proxy() {
  trace 1 "\n\n[wait_for_proxy] ${BCyan}Waiting for the proxy to be ready...${Color_Off}\n"

  # First ping the containers to make sure they're up...
  docker exec -t tests-manage-missed sh -c 'while true ; do ping -c 1 proxy ; [ "$?" -eq "0" ] && break ; sleep 5; done'

  # Now check if the lightning nodes are ready to accept requests...
  docker exec -t tests-manage-missed sh -c 'while true ; do curl proxy:8888/helloworld ; [ "$?" -eq "0" ] && break ; sleep 5; done'
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

  trace 1 "\n[test_manage_missed_0_conf] ${BCyan}Let's miss a 0-conf!...${Color_Off}"

  trace 2 "[test_manage_missed_0_conf] getnewaddress..."
  local response=$(exec_in_test_container curl -d '{"label":"missed0conftest"}' proxy:8888/getnewaddress)
  trace 3 "[test_manage_missed_0_conf] response=${response}"
  local address=$(echo "${response}" | jq -r ".address")
  trace 3 "[test_manage_missed_0_conf] address=${address}"

  trace 2 "[test_manage_missed_0_conf] watch it..."
  local data='{"address":"'${address}'","unconfirmedCallbackURL":"'${url1}'","confirmedCallbackURL":"'${url2}'","label":"missed0conftest"}'
  trace 3 "[test_manage_missed_0_conf] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
  trace 3 "[test_manage_missed_0_conf] response=${response}"

  trace 3 "[test_manage_missed_0_conf] Shutting down the proxy..."
  # There are two container names containing "proxy": proxy and proxycron
  # Let's exclude proxycron
  docker restart $(docker ps -q -f "name=proxy[^c]")

  trace 3 "[test_manage_missed_0_conf] Sending coins to watched address while proxy is down..."
  docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address} 0.0001
  # txid1=$(exec_in_test_container curl -d '{"address":"'${address}'","amount":0.0001}' proxy:8888/spend | jq -r ".txid")

  wait_for_proxy

  trace 3 "[test_manage_missed_0_conf] Calling executecallbacks..."
  exec_in_test_container curl -s -H "Content-Type: application/json" proxy:8888/executecallbacks

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

  trace 1 "\n[test_manage_missed_1_conf] ${BCyan}Let's miss a 1-conf!...${Color_Off}"

  trace 2 "[test_manage_missed_1_conf] getnewaddress..."
  local response=$(exec_in_test_container curl -d '{"label":"missed0conftest"}' proxy:8888/getnewaddress)
  trace 3 "[test_manage_missed_1_conf] response=${response}"
  local address=$(echo "${response}" | jq -r ".address")
  trace 3 "[test_manage_missed_1_conf] address=${address}"

  trace 2 "[test_manage_missed_1_conf] watch it..."
  local data='{"address":"'${address}'","unconfirmedCallbackURL":"'${url3}'","confirmedCallbackURL":"'${url4}'","label":"missed0conftest"}'
  trace 3 "[test_manage_missed_1_conf] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
  trace 3 "[test_manage_missed_1_conf] response=${response}"

  trace 3 "[test_manage_missed_1_conf] Sending coins to watched address while proxy is up..."
  docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address} 0.0001
  # txid1=$(exec_in_test_container curl -d '{"address":"'${address}'","amount":0.0001}' proxy:8888/spend | jq -r ".txid")

  trace 3 "[test_manage_missed_1_conf] Sleeping for 20 seconds to let the 0-conf callbacks to happen..."
  sleep 20

  trace 3 "[test_manage_missed_1_conf] Shutting down the proxy..."
  # There are two container names containing "proxy": proxy and proxycron
  # Let's exclude proxycron
  docker restart $(docker ps -q -f "name=proxy[^c]")

  trace 3 "[test_manage_missed_1_conf] Mine a new block..."
  mine

  wait_for_proxy

  trace 3 "[test_manage_missed_1_conf] Calling executecallbacks..."
  exec_in_test_container curl -s -H "Content-Type: application/json" proxy:8888/executecallbacks
}

wait_for_callbacks() {
  trace 1 "[wait_for_callbacks] ${BCyan}Let's start the callback servers!...${Color_Off}"

  docker exec -t tests-manage-missed sh -c "nc -vlp1111 -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'" &
  docker exec -t tests-manage-missed sh -c "nc -vlp1112 -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'" &
  docker exec -t tests-manage-missed sh -c "nc -vlp1113 -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'" &
  docker exec -t tests-manage-missed sh -c "nc -vlp1114 -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'" &
}

TRACING=3

stop_test_container
start_test_container
wait_for_callbacks

url1="tests-manage-missed:1111/callback0conf"
url2="tests-manage-missed:1112/callback1conf"
url3="tests-manage-missed:1113/callback0conf"
url4="tests-manage-missed:1114/callback1conf"
trace 2 "url1=${url1}"
trace 2 "url2=${url2}"
trace 2 "url3=${url3}"
trace 2 "url4=${url4}"

exec_in_test_container apk add --update curl

test_manage_missed_0_conf
test_manage_missed_1_conf

trace 3 "Waiting for the callbacks to happen..."
wait

stop_test_container
