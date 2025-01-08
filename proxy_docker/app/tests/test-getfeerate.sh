#!/bin/bash

. ./colors.sh

# You need jq installed for these tests to run correctly

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -t --name tests-getfeerate --network=cyphernodenet alpine:3.15.4
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop test-getfeerate
  local containers=$(docker ps -q -f "name=tests-getfeerate")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec -it tests-getfeerate "$@"
}

tests_getfeerate() {
  trace 1 "\n\n[tests_getfeerate] ${BCyan}Let's test the getfeerate features!...${Color_Off}\n"

  local current_mempool_values=$(curl -s -m 3 https://mempool.bullbitcoin.com/api/v1/fees/recommended)
  trace 2 "\n\n[tests_getfeerate] Current mempool.bullbitcoin.com values: ${Cyan}${current_mempool_values}${Color_Off}\n"

  # bitcoin_getfeerate
  # (POST) curl -d '{"confTarget":6}' proxy:8888/bitcoin_getfeerate
  # {"feerate":0.00000001,"errors":[]}

  trace 2 "\n\n[tests_getfeerate] ${BCyan}Testing getfeerate without confTarget...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{}" proxy:8888/bitcoin_getfeerate)
  trace 3 "[tests_getfeerate] response=${response}"
  local feerate=$(echo "${response}" | jq -r ".feerate")
  if ! [[ $feerate =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    return 130
  fi

  trace 2 "\n\n[tests_getfeerate] ${BCyan}Testing getfeerate with confTarget=20...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"confTarget\":20}" proxy:8888/bitcoin_getfeerate)
  trace 3 "[tests_getfeerate] response=${response}"
  local feerate=$(echo "${response}" | jq -r ".feerate")
  if ! [[ $feerate =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    return 130
  fi

  trace 2 "\n\n[tests_getfeerate] ${BCyan}Testing getfeerate with confTarget=10...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"confTarget\":10}" proxy:8888/bitcoin_getfeerate)
  trace 3 "[tests_getfeerate] response=${response}"
  local feerate=$(echo "${response}" | jq -r ".feerate")
  if ! [[ $feerate =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    return 130
  fi

  trace 2 "\n\n[tests_getfeerate] ${BCyan}Testing getfeerate with confTarget=6...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"confTarget\":6}" proxy:8888/bitcoin_getfeerate)
  trace 3 "[tests_getfeerate] response=${response}"
  local feerate=$(echo "${response}" | jq -r ".feerate")
  if ! [[ $feerate =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    return 130
  fi

  trace 2 "\n\n[tests_getfeerate] ${BCyan}Testing getfeerate with confTarget=3...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"confTarget\":3}" proxy:8888/bitcoin_getfeerate)
  trace 3 "[tests_getfeerate] response=${response}"
  local feerate=$(echo "${response}" | jq -r ".feerate")
  if ! [[ $feerate =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    return 130
  fi

  trace 2 "\n\n[tests_getfeerate] ${BCyan}Testing getfeerate with confTarget=1...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"confTarget\":1}" proxy:8888/bitcoin_getfeerate)
  trace 3 "[tests_getfeerate] response=${response}"
  local feerate=$(echo "${response}" | jq -r ".feerate")
  if ! [[ $feerate =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    return 130
  fi

  trace 2 "\n\n[tests_getfeerate] ${BCyan}Tested getfeerate.${Color_Off}\n"
}

TRACING=3
returncode=0

stop_test_container
start_test_container

trace 1 "\n\n[test-getfeerate] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container apk add --update curl

returncode=$(tests_getfeerate)

trace 1 "\n\n[test-getfeerate] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[test-getfeerate] ${BCyan}See ya!${Color_Off}\n"

exit ${returncode}
