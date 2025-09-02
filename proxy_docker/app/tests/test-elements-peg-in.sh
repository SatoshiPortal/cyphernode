#!/bin/bash

DIR="$( dirname -- "${BASH_SOURCE[0]}"; )";
. $DIR/colors.sh
. $DIR/mine.sh

# This needs to be run in regtest
# You need jq installed for these tests to run correctly
#
# Something like rpcworkqueue=1000 in bitcoin.conf is recommended due to the number of blocks we mine

# This will test the elements peg in and claim functionality
#
# - getpeginaddress
# - watchtx
# - executecallbacks
# - claimpegin
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

  local execcmd=("sh" "-c" "echo \"${cbserver_b64}\" | base64 -d > cb-server.sh && chmod +x cb-server.sh")
  exec_in_test_container "${execcmd[@]}"

  trace 1 "\n\n[create_cb_server] ${BCyan}Created cb-server.sh...${Color_Off}\n"
}

start_test_container() {
  docker run -d --rm -t --name tests-elements-peg-in --network=cyphernodenet alpine:3.15.4
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop tests-elements-peg-in
  local containers=$(docker ps -q -f "name=tests-elements-peg-in")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec -it tests-elements-peg-in "$@"
}

exec_in_test_container_nonint() {
  docker exec -t tests-elements-peg-in "$@"
}

wait_for_broker() {
  trace 1 "\n\n[wait_for_broker] ${BCyan}Waiting for the broker to be ready...${Color_Off}\n"

  # First ping the containers to make sure they're up...
  docker exec -t tests-elements-peg-in sh -c 'while true ; do ping -c 1 broker ; [ "$?" -eq "0" ] && break ; sleep 5; done'
}

test_elements_peg_in() {
  # 1. (elements) Get new peg in address
  # 2. (bitcoin) sendtoaddress
  # 3. (bitcoin) Watch txid for 102 confirmations
  # 4. (bitcoin) Mine 102 blocks
  # 5. (elements) Claim peg in
  # 6. (elements) Mine a new block
  # 7. (elements) Check balance

  trace 2 "[test_elements_peg_in] Check initial balance..."
  response=$(exec_in_test_container curl proxy:8888/elements_getbalance)
  trace 3 "[test_elements_peg_in] response=${response}"
  
  local startbalance=$(echo "${response}" | jq -r ".balance.bitcoin")
  trace 3 "[test_elements_peg_in] startbalance=${startbalance}"

  local id0=$RANDOM
  local id1=$RANDOM

  local port0=${id0}
  local port1=${id1}

  local callbackurl1conf="http://${callbackservername}:${port1}/callbackurl1conf"
  local callbackurlnconf="http://${callbackservername}:${port1}/callbackurlnconf"

  trace 1 "\n[test_elements_peg_in] ${BCyan}Let's peg in!...${Color_Off}"

  # 1. (elements) Get new peg in address
  trace 2 "[test_elements_peg_in] getpeginaddress..."
  local response=$(exec_in_test_container curl proxy:8888/elements_getpeginaddress)
  trace 3 "[test_elements_peg_in] response=${response}"
  local mainchain_address=$(echo "${response}" | jq -r ".result.mainchain_address")
  trace 3 "[test_elements_peg_in] mainchain_address=${mainchain_address}"
  local claim_script=$(echo "${response}" | jq -r ".result.claim_script")
  trace 3 "[test_elements_peg_in] claim_script=${claim_script}"

  mine 101 > /dev/null 2>&1

  # 2. (bitcoin) sendtoaddress
  trace 2 "[test_elements_peg_in] Sending coins to peg in address..."
  txid=$(docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${mainchain_address} 0.1 | tr -d "\r\n")
  trace 3 "[test_elements_peg_in] txid=${txid}"

  # 3. (bitcoin) Watch txid for 102 confirmations
  trace 2 "[test_elements_peg_in] watch it..."
  local data='{"txid":"'${txid}'","confirmedCallbackURL":"'${callbackurl1conf}'","xconfCallbackURL":"'${callbackurlnconf}'","nbxconf":102}'
  trace 3 "[test_elements_peg_in] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watchtxid)
  trace 3 "[test_elements_peg_in] response=${response}"

  # 4. (bitcoin) Mine 102 blocks
  trace 3 "[test_elements_peg_in] Mine 102 blocks..."
  mine 102 > /dev/null 2>&1

  trace 2 "[test_elements_peg_in] Start callback server for 102-conf webhook..."
  start_callback_server $port1 "102"

  trace 3 "[test_elements_peg_in] Waiting for 102-conf callbacks on txid..."
  
  # 5. (elements) Claim peg in
  local txoutproof=$(docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat gettxoutproof '["'${txid}'"]' | tr -d "\r\n")
  trace 3 "[test_elements_peg_in] txoutproof=${txoutproof}"

  local txhex=$(docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat getrawtransaction ${txid} | tr -d "\r\n")
  trace 3 "[test_elements_peg_in] txhex=${txhex}"

  trace 2 "[test_elements_peg_in] claimpegin..."
  local data='{"proof":"'${txoutproof}'","rawtx":"'${txhex}'","claim_script":"'${claim_script}'"}'
  trace 3 "[test_elements_peg_in] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/elements_claimpegin)
  trace 3 "[test_elements_peg_in] response=${response}"

  # 6. (elements) Mine a new block
  trace 2 "[test_elements_peg_in] Mine a block..."
  elements_mine

  # 7. (elements) Check balance
  trace 2 "[test_elements_peg_in] Check balance..."
  response=$(exec_in_test_container curl proxy:8888/elements_getbalance)
  trace 3 "[test_elements_peg_in] response=${response}"
  
  local balance=$(echo "${response}" | jq -r ".balance.bitcoin")
  if [ $(echo "${balance} > ${startbalance}" | bc -l) -eq 1 ]; then
    trace 1 "\n\n[test_elements_peg_in] ${On_IGreen}${BBlack} 1. elements_getbalance success!                                           ${Color_Off}\n"
    return 0
  else
    trace 1 "\n\n[test_elements_peg_in] ${On_Red}${BBlack} 1. elements_getbalance failed!                                           ${Color_Off}\n"
    return 10
  fi
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
callbackservername="tests-elements-peg-in"

test_elements_peg_in

stop_test_container
