#!/bin/bash

DIR="$( dirname -- "${BASH_SOURCE[0]}"; )"; 
. $DIR/colors.sh
. $DIR/mine.sh

# This needs to be run in regtest
# You need jq installed for these tests to run correctly

# This will test:
#
# - getnewaddress
# - watch
# - getactivewatches
# - unwatch
# - watchtxid
# - unwatchtxid
# - spend
#

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -t --name tests-watches --network=cyphernodenet alpine
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop tests-watches
  local containers=$(docker ps -q -f "name=tests-watches")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec tests-watches "$@"
}

test_watches() {

  # Watch addresses and a txid
  # 1. Call getnewaddress twice with label1 and label2
  # 2. Call watch on the address with label1
  # 3. Call watch on the address with label2

  # 4. Call getactivewatches, search for addresses with label1 and label2
  # 6. unwatch label2
  # 7. Call getactivewatches, check that label2 is not there

  # 9. Start a callback server for label1 watch 0-conf webhook
  # 10. Call spend, to the address with label1 (triggers 0-conf webhook)
  # 11. Wait for label1's 0-conf webhook

  # 12. Call watchtxid on spent txid with 3-conf webhook
  # 13. Start a callback servers for 1-conf txid watch webhook
  # 14. Generate a block (triggers 1-conf webhook)
  # 15. Wait for 1-conf webhook

  # 16. Start a callback servers for 3-conf txid watch webhook
  # 17. Generate 2 blocks (triggers 3-conf webhook)
  # 18. Wait for 3-conf webhook

  # 20. Call getactivewatches, make sure label1 and label2 are not there

  local label1="label$RANDOM"
  local label2="label$RANDOM"
  local callbackurl0conf1="tests-watches:1111/callbackurl0conf1"
  local callbackurl1conf1="tests-watches:1112/callbackurl1conf1"
  local callbackurl1conftxid="tests-watches:1113/callbackurl1conftxid"
  local callbackurl3conftxid="tests-watches:1114/callbackurl3conftxid"
  local address
  local address1
  local address2
  local txid
  local data
  local response

  trace 1 "\n\n[test_watches] ${BCyan}Let's test \"watch addresses and a txid\" features!...${Color_Off}\n"

  # 1. Call getnewaddress twice with label1 and label2
  trace 2 "\n\n[test_watches] ${BCyan}1. getnewaddress...${Color_Off}\n"
  data='{"label":"'${label1}'"}'
  trace 3 "[test_watches] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/getnewaddress)
  trace 3 "[test_watches] response=${response}"
  data=$(echo "${response}" | jq -re ".error")
  if [ "${?}" -eq "0" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 1. getnewaddress 1 failed: ${data}!                                           ${Color_Off}\n"
    return 10
  fi
  address1=$(echo "$response" | jq -r ".address")
  trace 3 "[test_watches] address1=${address1}"

  data='{"label":"'${label2}'"}'
  trace 3 "[test_watches] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/getnewaddress)
  trace 3 "[test_watches] response=${response}"
  data=$(echo "${response}" | jq -re ".error")
  if [ "${?}" -eq "0" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 1. getnewaddress 2 failed: ${data}!                                           ${Color_Off}\n"
    return 15
  fi
  address2=$(echo "$response" | jq -r ".address")
  trace 3 "[test_watches] address2=${address2}"

  # 2. Call watch on the address with label1
  trace 2 "\n\n[test_watches] ${BCyan}2. watch 1...${Color_Off}\n"
  local data='{"address":"'${address1}'","unconfirmedCallbackURL":"'${callbackurl0conf1}'","confirmedCallbackURL":"'${callbackurl1conf1}'","label":"watch_'${label1}'"}'
  trace 3 "[test_watches] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
  trace 3 "[test_watches] response=${response}"
  data=$(echo "${response}" | jq -re ".error")
  if [ "${?}" -eq "0" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 2. watch 1 failed: ${data}!                                           ${Color_Off}\n"
    return 20
  fi

  # 3. Call watch on the address with label2
  trace 2 "\n\n[test_watches] ${BCyan}3. watch 2...${Color_Off}\n"
  local data='{"address":"'${address2}'","unconfirmedCallbackURL":"dummy","confirmedCallbackURL":"dummy","label":"watch_'${label2}'"}'
  trace 3 "[test_watches] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watch)
  trace 3 "[test_watches] response=${response}"
  data=$(echo "${response}" | jq -re ".error")
  if [ "${?}" -eq "0" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 3. watch 2 failed: ${data}!                                           ${Color_Off}\n"
    return 25
  fi

  # 4. Call getactivewatches, search for addresses with label1 and label2
  trace 2 "\n\n[test_watches] ${BCyan}4. Call getactivewatches, search for addresses with label1 and label2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatches)
  # trace 3 "[test_watches] response=${response}"
  address=$(echo "${response}" | jq -r ".watches | map(select(.label == \"watch_${label1}\"))[0].address")
  trace 3 "[test_watches] address=${address}"
  if [ "${address}" != "${address1}" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 4. Call getactivewatches, search for address with label1: \"${address}\" != \"${address1}\"!                                           ${Color_Off}\n"
    return 30
  fi
  address=$(echo "${response}" | jq -r ".watches | map(select(.label == \"watch_${label2}\"))[0].address")
  trace 3 "[test_watches] address=${address}"
  if [ "${address}" != "${address2}" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 4. Call getactivewatches, search for address with label2: \"${address}\" != \"${address2}\"!                                           ${Color_Off}\n"
    return 35
  fi

  # 6. unwatch label2
  trace 2 "\n\n[test_watches] ${BCyan}6. unwatch label2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/unwatch/${address2})
  trace 3 "[test_watches] response=${response}"
  data=$(echo "${response}" | jq -re ".error")
  if [ "${?}" -eq "0" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 6. unwatch label2 failed: ${data}!                                           ${Color_Off}\n"
    return 40
  fi

  # 7. Call getactivewatches, check that label2 is not there
  trace 2 "\n\n[test_watches] ${BCyan}7. Call getactivewatches, check that label2 is not there...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatches)
  # trace 3 "[test_watches] response=${response}"
  address=$(echo "${response}" | jq -r ".watches | map(select(.label == \"watch_${label2}\"))[0].address")
  trace 3 "[test_watches] address=${address}"
  if [ "${address}" = "${address2}" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 4. Call getactivewatches, found address2: \"${address}\" = \"${address2}\"!                                           ${Color_Off}\n"
    return 50
  fi

  # 9. Start a callback server for label1 watch 0-conf webhook
  # 10. Call spend, to the address with label1 (triggers 0-conf webhook)
  # 11. Wait for label1's 0-conf webhook
  trace 2 "\n\n[test_watches] ${BCyan}10. Send coins to address1...${Color_Off}\n"
  start_callback_server 1111
  # Let's use the bitcoin node directly to better simulate an external spend
  txid=$(docker exec -it $(docker ps -q -f "name=cyphernode.bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address1} 0.0001 | tr -d "\r\n")
#  txid=$(exec_in_test_container curl -d '{"address":"'${address1}'","amount":0.001}' proxy:8888/spend | jq -r ".txid")
  trace 3 "[test_watches] txid=${txid}"
  trace 3 "[test_watches] Waiting for 0-conf callback on address1..."
  wait

  # 12. Call watchtxid on spent txid with 3-conf webhook
  trace 2 "\n\n[test_watches] ${BCyan}12. Call watchtxid on spent txid with 3-conf webhook...${Color_Off}\n"
  # BODY {"txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","xconfCallbackURL":"192.168.111.233:1111/callbackXconf","nbxconf":6}
  local data='{"txid":"'${txid}'","confirmedCallbackURL":"'${callbackurl1conftxid}'","xconfCallbackURL":"'${callbackurl3conftxid}'","nbxconf":3}'
  trace 3 "[test_watches] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watchtxid)
  trace 3 "[test_watches] response=${response}"
  data=$(echo "${response}" | jq -re ".error")
  if [ "${?}" -eq "0" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 12. Call watchtxid on spent txid with 3-conf webhook failed: ${data}!                                           ${Color_Off}\n"
    return 60
  fi

  # 13. Start a callback servers for 1-conf txid watch webhook
  trace 2 "\n\n[test_watches] ${BCyan}13. Start a callback servers for 1-conf txid watch webhook...${Color_Off}\n"
  start_callback_server 1112
  start_callback_server 1113

  # 14. Generate a block (triggers 1-conf webhook)
  trace 3 "[test_manage_missed_1_conf] Mine a new block..."
  mine

  # 15. Wait for 1-conf webhook
  trace 3 "[test_watches] Waiting for 1-conf callbacks on address1 and txid..."
  wait

  # 16. Start a callback servers for 3-conf txid watch webhook
  trace 2 "\n\n[test_watches] ${BCyan}16. Start a callback servers for 3-conf txid watch webhook...${Color_Off}\n"
  start_callback_server 1114

  # 17. Generate 2 blocks (triggers 3-conf webhook)
  trace 3 "[test_watches] Mine 2 new blocks..."
  mine 2

  # 18. Wait for 3-conf webhook
  trace 3 "[test_watches] Waiting for 3-conf callback on txid..."
  wait

  # 20. Call getactivewatches, make sure label1 and label2 are not there
  trace 2 "\n\n[test_watches] ${BCyan}20. Call getactivewatches, make sure label1 and label2 are not there...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatches)
  # trace 3 "[test_watches] response=${response}"
  address=$(echo "${response}" | jq -r ".watches | map(select(.label == \"watch_${label1}\"))[0].address")
  trace 3 "[test_watches] address=${address}"
  if [ "${address}" = "${address1}" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 4. Call getactivewatches, found address1: \"${address}\" = \"${address1}\"!                                           ${Color_Off}\n"
    return 70
  fi
  address=$(echo "${response}" | jq -r ".watches | map(select(.label == \"watch_${label2}\"))[0].address")
  trace 3 "[test_watches] address=${address}"
  if [ "${address}" = "${address2}" ]; then
    trace 1 "\n\n[test_watches] ${On_Red}${BBlack} 4. Call getactivewatches, found address2: \"${address}\" = \"${address2}\"!                                           ${Color_Off}\n"
    return 75
  fi

  trace 1 "\n\n[test_watches] ${On_IGreen}${BBlack} ALL GOOD!  Yayyyy!                                           ${Color_Off}\n"
}

start_callback_server() {
  trace 1 "[start_callback_server] ${BCyan}Let's start the callback servers!...${Color_Off}"

  local port=${1:-1111}

  docker exec -t tests-watches sh -c "nc -vlp${port} -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'" &
}

TRACING=3
returncode=0

stop_test_container
start_test_container

trace 1 "\n\n[test_watches] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container apk add --update curl

#returncode=$(test_watches)
test_watches

trace 1 "\n\n[test_watches] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[test_watches] ${BCyan}See ya!${Color_Off}\n"

exit ${returncode}
