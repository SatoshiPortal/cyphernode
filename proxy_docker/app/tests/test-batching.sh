#!/bin/sh

. ./colors.sh

# This needs to be run in regtest
# You need jq installed for these tests to run correctly

# This will test:
#
# - listbatchers
# - getbatcher
# - getbatchdetails
# - getnewaddress
# - addtobatch
# - batchspend
# - removefrombatch
# - createbatcher
#






# Notes:
# curl proxy:8888/listbatchers | jq
# curl -d '{}' proxy:8888/getbatcher | jq
# curl -d '{}' proxy:8888/getbatchdetails | jq
# curl -d '{"outputLabel":"test002","address":"1abd","amount":0.0002}' proxy:8888/addtobatch | jq
# curl -d '{}' proxy:8888/batchspend | jq
# curl -d '{"outputId":1}' proxy:8888/removefrombatch | jq

# curl -d '{"batcherLabel":"lowfees","confTarget":32}' proxy:8888/createbatcher | jq
# curl proxy:8888/listbatchers | jq

# curl -d '{"batcherLabel":"lowfees"}' proxy:8888/getbatcher | jq
# curl -d '{"batcherLabel":"lowfees"}' proxy:8888/getbatchdetails | jq
# curl -d '{"batcherLabel":"lowfees","outputLabel":"test002","address":"1abd","amount":0.0002}' proxy:8888/addtobatch | jq
# curl -d '{"batcherLabel":"lowfees"}' proxy:8888/batchspend | jq
# curl -d '{"batcherLabel":"lowfees","outputId":9}' proxy:8888/removefrombatch | jq


trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -it --name tests-batching --network=cyphernodenet alpine
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  docker stop tests-batching
  docker stop tests-batching-cb
}

exec_in_test_container() {
  docker exec -it tests-batching "$@"
}


testbatching() {
  trace 1 "\n\n[testbatching] ${BCyan}Let's test batching features!...${Color_Off}\n"

  local response
  local id
  local id2
  local data
  local data2
  local address1
  local address2
  local amount1
  local amount2

  local url1="$(hostname):1111/callback"
  echo "url1=${url1}"
  local url2="$(hostname):1112/callback"
  echo "url2=${url2}"

  # List batchers (should show at least empty default batcher)
  trace 2 "\n\n[testbatching] ${BCyan}Testing listbatchers...${Color_Off}\n"
  response=$(exec_in_test_container curl -s proxy:8888/listbatchers)
  trace 3 "[testbatching] response=${response}"
  id=$(echo "${response}" | jq ".result[0].batcherId")
  trace 3 "[testbatching] batcherId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 10
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested listbatchers.${Color_Off}\n"

  # getbatcher the default batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing getbatcher...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{}' proxy:8888/getbatcher)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherLabel")
  trace 3 "[testbatching] batcherLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 20
  fi

  response=$(exec_in_test_container curl -sd '{"batcherId":1}' proxy:8888/getbatcher)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherLabel")
  trace 3 "[testbatching] batcherLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 25
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested getbatcher.${Color_Off}\n"

  # getbatchdetails the default batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing getbatchdetails...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{}' proxy:8888/getbatchdetails)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherLabel")
  trace 3 "[testbatching] batcherLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 30
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 32
  fi

  response=$(exec_in_test_container curl -sd '{"batcherId":1}' proxy:8888/getbatchdetails)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherLabel")
  trace 3 "[testbatching] batcherLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 35
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 37
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested getbatchdetails.${Color_Off}\n"

  # addtobatch to default batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing addtobatch...${Color_Off}\n"
  address1=$(exec_in_test_container curl -s proxy:8888/getnewaddress | jq -r ".address")
  trace 3 "[testbatching] address1=${address1}"
  response=$(exec_in_test_container curl -sd '{"outputLabel":"test001","address":"'${address1}'","amount":0.001}' proxy:8888/addtobatch)
  trace 3 "[testbatching] response=${response}"
  id=$(echo "${response}" | jq ".result.batcherId")
  trace 3 "[testbatching] batcherId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 40
  fi
  id=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 42
  fi
  trace 3 "[testbatching] outputId=${id}"

  address2=$(exec_in_test_container curl -s proxy:8888/getnewaddress | jq -r ".address")
  trace 3 "[testbatching] address2=${address2}"
  response=$(exec_in_test_container curl -sd '{"batcherId":1,"outputLabel":"test002","address":"'${address2}'","amount":22000000}' proxy:8888/addtobatch)
  trace 3 "[testbatching] response=${response}"
  id2=$(echo "${response}" | jq ".result.batcherId")
  trace 3 "[testbatching] batcherId=${id2}"
  if [ "${id2}" -ne "1" ]; then
    exit 47
  fi
  id2=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 50
  fi
  trace 3 "[testbatching] outputId=${id2}"
  trace 2 "\n\n[testbatching] ${BCyan}Tested addtobatch.${Color_Off}\n"

  # batchspend default batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing batchspend...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{}' proxy:8888/batchspend)
  trace 3 "[testbatching] response=${response}"
  echo "${response}" | jq -e ".error"
  if [ "$?" -ne 0 ]; then
    exit 55
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested batchspend.${Color_Off}\n"

  # getbatchdetails the default batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing getbatchdetails...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{}' proxy:8888/getbatchdetails)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq ".result.nbOutputs")
  trace 3 "[testbatching] nbOutputs=${data}"
  trace 2 "\n\n[testbatching] ${BCyan}Tested getbatchdetails.${Color_Off}\n"

  # removefrombatch from default batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing removefrombatch...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{"outputId":'${id}'}' proxy:8888/removefrombatch)
  trace 3 "[testbatching] response=${response}"
  id=$(echo "${response}" | jq ".result.batcherId")
  trace 3 "[testbatching] batcherId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 60
  fi

  response=$(exec_in_test_container curl -sd '{"outputId":'${id2}'}' proxy:8888/removefrombatch)
  trace 3 "[testbatching] response=${response}"
  id=$(echo "${response}" | jq ".result.batcherId")
  trace 3 "[testbatching] batcherId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 64
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested removefrombatch.${Color_Off}\n"

  # getbatchdetails the default batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing getbatchdetails...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{"batcherId":1}' proxy:8888/getbatchdetails)
  trace 3 "[testbatching] response=${response}"
  data2=$(echo "${response}" | jq ".result.nbOutputs")
  trace 3 "[testbatching] nbOutputs=${data2}"
  if [ "${data2}" -ne "$((${data}-2))" ]; then
    exit 68
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested getbatchdetails.${Color_Off}\n"



  # Create a batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing createbatcher...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H 'Content-Type: application/json' -d '{"batcherLabel":"testbatcher","confTarget":32}' proxy:8888/createbatcher)
  trace 3 "[testbatching] response=${response}"
  id=$(echo "${response}" | jq -e ".result.batcherId")
  if [ "$?" -ne "0" ]; then
    exit 70
  fi

  # List batchers (should show at least default and testbatcher batchers)
  trace 2 "\n\n[testbatching] ${BCyan}Testing listbatches...${Color_Off}\n"
  response=$(exec_in_test_container curl -s proxy:8888/listbatchers)
  trace 3 "[testbatching] response=${response}"
  id=$(echo "${response}" | jq '.result[] | select(.batcherLabel == "testbatcher") | .batcherId')
  trace 3 "[testbatching] batcherId=${id}"
  if [ -z "${id}" ]; then
    exit 75
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested listbatchers.${Color_Off}\n"

  # getbatcher the testbatcher batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing getbatcher...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{"batcherId":'${id}'}' proxy:8888/getbatcher)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherLabel")
  trace 3 "[testbatching] batcherLabel=${data}"
  if [ "${data}" != "testbatcher" ]; then
    exit 80
  fi

  response=$(exec_in_test_container curl -sd '{"batcherLabel":"testbatcher"}' proxy:8888/getbatcher)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherId")
  trace 3 "[testbatching] batcherId=${data}"
  if [ "${data}" != "${id}" ]; then
    exit 90
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested getbatcher.${Color_Off}\n"

  # getbatchdetails the testbatcher batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing getbatchdetails...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{"batcherLabel":"testbatcher"}' proxy:8888/getbatchdetails)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherId")
  trace 3 "[testbatching] batcherId=${data}"
  if [ "${data}" != "${id}" ]; then
    exit 100
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 110
  fi

  response=$(exec_in_test_container curl -sd '{"batcherId":'${id}'}' proxy:8888/getbatchdetails)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq -r ".result.batcherLabel")
  trace 3 "[testbatching] batcherLabel=${data}"
  if [ "${data}" != "testbatcher" ]; then
    exit 120
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 130
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested getbatchdetails.${Color_Off}\n"

  # addtobatch to testbatcher batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing addtobatch...${Color_Off}\n"
  address1=$(exec_in_test_container curl -s proxy:8888/getnewaddress | jq -r ".address")
  trace 3 "[testbatching] address1=${address1}"
  response=$(exec_in_test_container curl -sd '{"batcherId":'${id}',"outputLabel":"test001","address":"'${address1}'","amount":0.001,"webhookUrl":"'${url1}'/'${address1}'"}' proxy:8888/addtobatch)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq ".result.batcherId")
  trace 3 "[testbatching] batcherId=${data}"
  if [ "${data}" -ne "${id}" ]; then
    exit 140
  fi
  id2=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 142
  fi
  trace 3 "[testbatching] outputId=${id2}"

  address2=$(exec_in_test_container curl -s proxy:8888/getnewaddress | jq -r ".address")
  trace 3 "[testbatching] address2=${address2}"
  response=$(exec_in_test_container curl -sd '{"batcherLabel":"testbatcher","outputLabel":"test002","address":"'${address2}'","amount":0.002,"webhookUrl":"'${url2}'/'${address2}'"}' proxy:8888/addtobatch)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq ".result.batcherId")
  trace 3 "[testbatching] batcherId=${data}"
  if [ "${data}" -ne "${id}" ]; then
    exit 150
  fi
  id2=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 152
  fi
  trace 3 "[testbatching] outputId=${id2}"
  trace 2 "\n\n[testbatching] ${BCyan}Tested addtobatch.${Color_Off}\n"

  # batchspend testbatcher batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing batchspend...${Color_Off}\n"
  response=$(exec_in_test_container curl -sd '{"batcherLabel":"testbatcher"}' proxy:8888/batchspend)
  trace 3 "[testbatching] response=${response}"
  data2=$(echo "${response}" | jq -e ".result.txid")
  if [ "$?" -ne 0 ]; then
    exit 160
  fi
  trace 3 "[testbatching] txid=${data2}"
  data=$(echo "${response}" | jq ".result.outputs | length")
  if [ "${data}" -ne "2" ]; then
    exit 162
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested batchspend.${Color_Off}\n"

  # getbatchdetails the testbatcher batcher
  trace 2 "\n\n[testbatching] ${BCyan}Testing getbatchdetails...${Color_Off}\n"
  trace 3 "[testbatching] txid=${data2}"
  response=$(exec_in_test_container curl -sd '{"batcherLabel":"testbatcher","txid":'${data2}'}' proxy:8888/getbatchdetails)
  trace 3 "[testbatching] response=${response}"
  data=$(echo "${response}" | jq ".result.nbOutputs")
  trace 3 "[testbatching] nbOutputs=${data}"
  if [ "${data}" -ne "2" ]; then
    exit 170
  fi
  trace 2 "\n\n[testbatching] ${BCyan}Tested getbatchdetails.${Color_Off}\n"

  # List batchers
  # Add to batch
  # List batchers
  # Remove from batch
  # List batchers

  trace 1 "\n\n[testbatching] ${On_IGreen}${BBlack} ALL GOOD!  Yayyyy!                                           ${Color_Off}\n"

}

start_callback_server() {
  trace 1 "\n\n[start_callback_server] ${BCyan}Let's start a callback server!...${Color_Off}\n"

  port=${1:-${callbackserverport}}
  docker run --rm -t --name tests-batching-cb --network=cyphernodenet alpine sh -c "nc -vlp${port} -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'" &
}

TRACING=3

stop_test_container
start_test_container

callbackserverport="1111"
callbackservername="tests-batching-cb"

trace 1 "\n\n[test-batching] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container apk add --update curl

testbatching

trace 1 "\n\n[test-batching] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[test-batching] ${BCyan}See ya!${Color_Off}\n"
