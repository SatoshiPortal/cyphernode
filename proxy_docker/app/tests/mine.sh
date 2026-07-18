#!/bin/bash

# This needs to be run in regtest

# This will mine n blocks.  If n is not supplied, will mine 1 block.

# Mine
container_by_service() {
  local service=${1}
  local legacy_name_filter=${2}
  local explicit_container=${3:-}
  local container_id

  if [ -n "${explicit_container}" ]; then
    container_id=$(docker ps -q -f "name=${explicit_container}" | head -n 1)
  fi

  if [ -z "${container_id}" ]; then
    container_id=$(docker ps -q -f "name=${legacy_name_filter}" | head -n 1)
  fi

  if [ -z "${container_id}" ]; then
    container_id=$(docker ps -q -f "label=com.docker.compose.service=${service}" | head -n 1)
  fi

  if [ -z "${container_id}" ]; then
    container_id=$(docker ps -q -f "name=${service}" | head -n 1)
  fi

  if [ -z "${container_id}" ]; then
    echo "Could not find running ${service} container" >&2
    return 1
  fi

  echo "${container_id}"
}

bitcoin_container() {
  local wallet_suffix=${1:-}
  container_by_service bitcoin "cyphernode_bitcoin${wallet_suffix}\\." "${CYPHERNODE_TEST_BITCOIN_CONTAINER:-}"
}

elements_container() {
  container_by_service elements "cyphernode_elements" "${CYPHERNODE_TEST_ELEMENTS_CONTAINER:-}"
}

proxy_container() {
  container_by_service proxy "proxy[^c]" "${CYPHERNODE_TEST_PROXY_CONTAINER:-}"
}

broker_container() {
  container_by_service broker "broker" "${CYPHERNODE_TEST_BROKER_CONTAINER:-}"
}

stop_proxy_for_test() {
  CYPHERNODE_TEST_STOPPED_PROXY_CONTAINER=$(proxy_container) || return $?
  export CYPHERNODE_TEST_STOPPED_PROXY_CONTAINER
  docker stop "${CYPHERNODE_TEST_STOPPED_PROXY_CONTAINER}"
}

start_proxy_for_test() {
  local container_id=${CYPHERNODE_TEST_STOPPED_PROXY_CONTAINER:-}
  if [ -z "${container_id}" ]; then
    container_id=$(proxy_container) || return $?
  fi
  docker start "${container_id}"
}

stop_broker_for_test() {
  CYPHERNODE_TEST_STOPPED_BROKER_CONTAINER=$(broker_container) || return $?
  export CYPHERNODE_TEST_STOPPED_BROKER_CONTAINER
  docker stop "${CYPHERNODE_TEST_STOPPED_BROKER_CONTAINER}"
}

start_broker_for_test() {
  local container_id=${CYPHERNODE_TEST_STOPPED_BROKER_CONTAINER:-}
  if [ -z "${container_id}" ]; then
    container_id=$(broker_container) || return $?
  fi
  docker start "${container_id}"
}

mine() {
  local nbblocks=${1:-1}
  local wallet_suffix=${2:-}
  local container_id

  echo ; echo "About to mine ${nbblocks} block(s)..."
  container_id=$(bitcoin_container "${wallet_suffix}") || return $?
  docker exec "${container_id}" bitcoin-cli -rpcwallet=spending01.dat -generate ${nbblocks}
}

elements_mine() {
  local nbblocks=${1:-1}
  local container_id

  echo ; echo "About to mine ${nbblocks} block(s)..."
  container_id=$(elements_container) || return $?
  docker exec "${container_id}" elements-cli -rpcwallet=spending01.dat -generate ${nbblocks}
}

case "${1}" in
  elements) shift; elements_mine $@;;
  bitcoin) shift; mine $@;;
esac
