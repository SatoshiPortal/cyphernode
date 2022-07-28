#!/bin/bash

DIR="$( dirname -- "${BASH_SOURCE[0]}"; )"; 
. $DIR/colors.sh
. $DIR/mine.sh


# This needs to be run in regtest
# You need jq installed for these tests to run correctly
#
# It will add watch addresses with no callback listening 
# We had to create this to inject 10 wrong callbacks and run test-manage-missed.sh
# When we switched to Debian, the request thread was getting killed when a subprocess was writing to stdout.  Turns out we made a
# fix in the request handler to redirects stdout into a variable instead of the actual output stream.  Debian netcat was killing the thread
# when the caller (curl) was closing the connection after receiving a non HTTP 1.1 response


trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -t --name tests-make-watch-noise --network=cyphernodenet alpine
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop tests-make-watch-noise
  local containers=$(docker ps -q -f "name=tests-make-watch-noise")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec -it tests-make-watch-noise "$@"
}

make_watch_noise(){
  local me="${BCyan}make_watch_noise${Color_Off}"
  local noise_level=${1:-1}

  trace 1 "[${me}] ${BCyan}Let's ${me} - ${noise_level}...${Color_Off}"

  for ((loop=0; loop<${noise_level}; loop++));
  do
    local port=$RANDOM
    local url0="tests-make-watch-noise:${port}/NEVERcallback0conf${port}"
    local url1="tests-make-watch-noise:${port}/NEVERcallback1conf${port}"

    trace 2 "[${me}] getnewaddress..."
    local response=$(exec_in_test_container curl -d '{"label":"make some noise '${loop}'"}' proxy:8888/getnewaddress)
    trace 3 "[${me}] response=${response}"
    local address=$(echo "${response}" | jq -r ".address")
    trace 3 "[${me}] address=${address}"

    trace 2 "[${me}] watch it..."
    local data='{"address":"'${address}'","unconfirmedCallbackURL":"'${url0}'","confirmedCallbackURL":"'${url1}'","label":"label make some noise '${port}'"}'
    trace 3 "[${me}] data=${data}"
    response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
    trace 3 "[${me}] response=${response}"

    trace 3 "[${me}] Sending coins to watched address..."
    docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address} 0.00001234
  done

  mine

  trace 1 "[${me}] ${BCyan}Done${Color_Off}"
}

TRACING=3

stop_test_container
start_test_container

exec_in_test_container apk add --update curl

make_watch_noise "$@"

stop_test_container
