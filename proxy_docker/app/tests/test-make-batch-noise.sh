#!/bin/bash

DIR="$( dirname -- "${BASH_SOURCE[0]}"; )"; 
. $DIR/colors.sh

# This needs to be run in regtest
# You need jq installed for these tests to run correctly

# This will add fake batch entries :
#
#

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -t --name tests-make-batch-noise --network=cyphernodenet alpine:3.15.4
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop tests-batching
  # docker stop tests-batching-cb
  local containers=$(docker ps -q -f "name=tests-make-batch-noise")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec -it tests-make-batch-noise "$@"
}


testmakebatchnoise() {
  trace 1 "\n\n[testbatching] ${BCyan}Let's test batching features!...${Color_Off}\n"

  local response
  local id
  local id2
  local address1

  local me="${BCyan}make_batch_noise${Color_Off}"
  local noise_level=${1:-1}

  trace 1 "[${me}] ${BCyan}Let's testmakebatchnoise - ${noise_level}...${Color_Off}"

  # List batchers (should show at least empty default batcher)
  trace 2 "\n\n[testbatching] ${BCyan}Testing listbatchers...${Color_Off}\n"
  response=$(exec_in_test_container curl -s proxy:8888/listbatchers)
  trace 3 "[testbatching] response=${response}"
  id=$(echo "${response}" | jq ".result[0].batcherId")
  trace 3 "[testbatching] batcherId=${id}"
  if [ "${id}" -ne "1" ]; then
    trace 1 "\n\n[testbatching] ${On_IRed}${BBlack} Failed!                                           ${Color_Off}\n"
    exit 10
  fi

  for ((loop=0; loop<${noise_level}; loop++));
  do
    local url1="$(hostname):$RANDOM/callback$RANDOM"
    echo "url1=${url1}"
    local url2="$(hostname):$RANDOM/callback$RANDOM"
    echo "url2=${url2}"

    # addtobatch to default batcher
    trace 2 "\n\n[testbatching] ${BCyan}Testing addtobatch...${Color_Off}\n"
    address1=$(exec_in_test_container curl -s proxy:8888/getnewaddress | jq -r ".address")
    trace 3 "[testbatching] address1=${address1}"
    trace 3 "[testbatching] curl -sd '{\"batcherId\":'${id}',\"outputLabel\":\"test001\",\"address\":\"'${address1}'\",\"amount\":0.006,\"webhookUrl\":\"'${url1}'/'${address1}'\"}' proxy:8888/addtobatch"
    response=$(exec_in_test_container curl -sd '{"batcherId":'${id}',"outputLabel":"test001","address":"'${address1}'","amount":0.006,"webhookUrl":"'${url1}'/'${address1}'"}' proxy:8888/addtobatch)
    trace 3 "[testbatching] response=${response}"
    id=$(echo "${response}" | jq ".result.batcherId")
    trace 3 "[testbatching] batcherId=${id}"
    if [ "${id}" -ne "1" ]; then
      trace 1 "\n\n[testbatching] ${On_IRed}${BBlack} Failed!                                           ${Color_Off}\n"
      exit 40
    fi
  
    id2=$(echo "${response}" | jq -e ".result.outputId")
    if [ "$?" -ne 0 ]; then
      trace 1 "\n\n[testbatching] ${On_IRed}${BBlack} Failed!                                           ${Color_Off}\n"
      exit 42
    fi
    trace 3 "[testbatching] outputId=${id}"
  done

  trace 2 "\n\n[testbatching] ${BCyan}Testing batchspend...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{}' proxy:8888/batchspend)
  trace 3 "[testbatching] response=${response}"
  echo "${response}" | jq -e ".error"

  # Expect a failure here
  if [ "$?" -eq 0 ]; then
    trace 1 "\n\n[testbatching] ${On_IRed}${BBlack} Failed!                                           ${Color_Off}\n"
    exit 55
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested batchspend.${Color_Off}\n"

  trace 1 "\n\n[testbatching] ${On_IGreen}${BBlack} ALL GOOD!  Yayyyy!                                           ${Color_Off}\n"
}

TRACING=3

stop_test_container
start_test_container

trace 1 "\n\n[test-make-batch-noise] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container apk add --update curl

testmakebatchnoise "$@"

trace 1 "\n\n[test-make-batch-noise] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[test-make-batch-noise] ${BCyan}See ya!${Color_Off}\n"
