#!/bin/bash

DIR="$( dirname -- "${BASH_SOURCE[0]}"; )"
. "$DIR/colors.sh"

# This should be run against a regtest deployment with the Elements feature enabled.

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -t --name tests-elements-getbalances --network=cyphernodenet alpine:3.15.4
}

stop_test_container() {
  local containers
  containers=$(docker ps -q -f "name=tests-elements-getbalances")
  if [ -n "${containers}" ]; then
    docker stop ${containers} >/dev/null
  fi
}

exec_in_test_container() {
  docker exec tests-elements-getbalances "$@"
}

balances_match() {
  local response="$1"
  local direct="$2"

  echo "${response}" | jq -e --argjson expected "${direct}" \
    '.balances == $expected' >/dev/null
}

test_elements_getbalances() {
  local bitcoin_container
  local elements_container
  local response
  local direct
  local http_code

  bitcoin_container=$(docker ps -q -f "network=cyphernodenet" \
    -f "label=com.docker.compose.service=bitcoin")
  elements_container=$(docker ps -q -f "network=cyphernodenet" \
    -f "label=com.docker.compose.service=elements")
  [ -n "${bitcoin_container}" ] || return 4
  [ -n "${elements_container}" ] || return 5

  trace 1 "[test_elements_getbalances] Verifying the legacy Bitcoin selector..."
  response=$(exec_in_test_container curl -s proxy:8888/getbalances/01)
  direct=$(docker exec -t "${bitcoin_container}" \
    bitcoin-cli -rpcwallet=spending01.dat getbalances | tr -d '\r')
  balances_match "${response}" "${direct}" || return 8

  trace 1 "[test_elements_getbalances] Verifying the default Bitcoin wallet remains available..."
  response=$(exec_in_test_container curl -s proxy:8888/getbalances)
  balances_match "${response}" "${direct}" || return 9

  trace 1 "[test_elements_getbalances] Querying an exact, non-spender Bitcoin wallet name..."
  response=$(exec_in_test_container curl -s \
    -H "Content-Type: application/json" \
    --data '{"walletName":"watching01.dat"}' \
    proxy:8888/getbalances)
  direct=$(docker exec -t "${bitcoin_container}" \
    bitcoin-cli -rpcwallet=watching01.dat getbalances | tr -d '\r')
  balances_match "${response}" "${direct}" || return 10

  trace 1 "[test_elements_getbalances] Querying spending01.dat through the wallet-scoped endpoint..."
  response=$(exec_in_test_container curl -s proxy:8888/elements_getbalances/01)
  echo "${response}" | jq -e '
    .balances.mine.trusted
    and .balances.mine.untrusted_pending
    and .balances.mine.immature
  ' >/dev/null || return 10

  direct=$(docker exec -t "${elements_container}" \
    elements-cli -rpcwallet=spending01.dat getbalances | tr -d '\r')
  balances_match "${response}" "${direct}" || return 20

  trace 1 "[test_elements_getbalances] Verifying the default Elements wallet remains available..."
  response=$(exec_in_test_container curl -s proxy:8888/elements_getbalances)
  balances_match "${response}" "${direct}" || return 30

  trace 1 "[test_elements_getbalances] Querying an exact, non-spender Elements wallet name..."
  response=$(exec_in_test_container curl -s \
    -H "Content-Type: application/json" \
    --data '{"walletName":"watching01.dat"}' \
    proxy:8888/elements_getbalances)
  direct=$(docker exec -t "${elements_container}" \
    elements-cli -rpcwallet=watching01.dat getbalances | tr -d '\r')
  balances_match "${response}" "${direct}" || return 35

  trace 1 "[test_elements_getbalances] Verifying an unknown selector does not fall back..."
  http_code=$(exec_in_test_container curl -s -o /dev/null -w "%{http_code}" \
    proxy:8888/elements_getbalances/999999)
  [ "${http_code}" = "400" ] || return 40

  trace 1 "[test_elements_getbalances] Verifying an unknown exact name does not fall back..."
  http_code=$(exec_in_test_container curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    --data '{"walletName":"definitely-not-a-wallet.dat"}' \
    proxy:8888/elements_getbalances)
  [ "${http_code}" = "400" ] || return 45

  trace 1 "[test_elements_getbalances] Rejecting an empty exact name before wallet lookup..."
  http_code=$(exec_in_test_container curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    --data '{"walletName":""}' \
    proxy:8888/elements_getbalances)
  [ "${http_code}" = "400" ] || return 50

  trace 1 "[test_elements_getbalances] ${On_IGreen}${BBlack}SUCCESS${Color_Off}"
}

TRACING=3

stop_test_container
trap stop_test_container EXIT
start_test_container >/dev/null
exec_in_test_container apk add --no-cache curl >/dev/null

test_elements_getbalances
