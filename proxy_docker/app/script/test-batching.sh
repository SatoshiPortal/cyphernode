#!/bin/sh

# curl localhost:8888/listbatches | jq
# curl -d '{}' localhost:8888/getbatch | jq
# curl -d '{}' localhost:8888/getbatchdetails | jq
# curl -d '{"outputLabel":"test002","address":"1abd","amount":0.0002}' localhost:8888/addtobatch | jq
# curl -d '{}' localhost:8888/batchspend | jq
# curl -d '{"outputId":1}' localhost:8888/removefrombatch | jq

# curl -d '{"batchLabel":"lowfees","confTarget":32}' localhost:8888/createbatch | jq
# curl localhost:8888/listbatches | jq

# curl -d '{"batchLabel":"lowfees"}' localhost:8888/getbatch | jq
# curl -d '{"batchLabel":"lowfees"}' localhost:8888/getbatchdetails | jq
# curl -d '{"batchLabel":"lowfees","outputLabel":"test002","address":"1abd","amount":0.0002}' localhost:8888/addtobatch | jq
# curl -d '{"batchLabel":"lowfees"}' localhost:8888/batchspend | jq
# curl -d '{"batchLabel":"lowfees","outputId":9}' localhost:8888/removefrombatch | jq

testbatching() {
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

  # List batches (should show at least empty default batch)
  echo "Testing listbatches..."
  response=$(curl -s proxy:8888/listbatches)
  echo "response=${response}"
  id=$(echo "${response}" | jq ".result[0].batchId")
  echo "batchId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 10
  fi
  echo "Tested listbatches."

  # getbatch the default batch
  echo "Testing getbatch..."
  response=$(curl -sd '{}' localhost:8888/getbatch)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchLabel")
  echo "batchLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 20
  fi

  response=$(curl -sd '{"batchId":1}' localhost:8888/getbatch)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchLabel")
  echo "batchLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 25
  fi
  echo "Tested getbatch."

  # getbatchdetails the default batch
  echo "Testing getbatchdetails..."
  response=$(curl -sd '{}' localhost:8888/getbatchdetails)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchLabel")
  echo "batchLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 30
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 32
  fi

  response=$(curl -sd '{"batchId":1}' localhost:8888/getbatchdetails)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchLabel")
  echo "batchLabel=${data}"
  if [ "${data}" != "default" ]; then
    exit 35
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 37
  fi
  echo "Tested getbatchdetails."

  # addtobatch to default batch
  echo "Testing addtobatch..."
  response=$(curl -sd '{"outputLabel":"test001","address":"test001","amount":0.001}' localhost:8888/addtobatch)
  echo "response=${response}"
  id=$(echo "${response}" | jq ".result.batchId")
  echo "batchId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 40
  fi
  id=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 42
  fi
  echo "outputId=${id}"

  response=$(curl -sd '{"batchId":1,"outputLabel":"test002","address":"test002","amount":0.002}' localhost:8888/addtobatch)
  echo "response=${response}"
  id2=$(echo "${response}" | jq ".result.batchId")
  echo "batchId=${id2}"
  if [ "${id2}" -ne "1" ]; then
    exit 40
  fi
  id2=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 42
  fi
  echo "outputId=${id2}"
  echo "Tested addtobatch."

  # batchspend default batch
  echo "Testing batchspend..."
  response=$(curl -sd '{}' localhost:8888/batchspend)
  echo "response=${response}"
  echo "${response}" | jq -e ".error"
  if [ "$?" -ne 0 ]; then
    exit 44
  fi
  echo "Tested batchspend."

  # getbatchdetails the default batch
  echo "Testing getbatchdetails..."
  response=$(curl -sd '{}' localhost:8888/getbatchdetails)
  echo "response=${response}"
  data=$(echo "${response}" | jq ".result.nbOutputs")
  echo "nbOutputs=${data}"
  echo "Tested getbatchdetails."

  # removefrombatch from default batch
  echo "Testing removefrombatch..."
  response=$(curl -sd '{"outputId":'${id}'}' localhost:8888/removefrombatch)
  echo "response=${response}"
  id=$(echo "${response}" | jq ".result.batchId")
  echo "batchId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 50
  fi

  response=$(curl -sd '{"outputId":'${id2}'}' localhost:8888/removefrombatch)
  echo "response=${response}"
  id=$(echo "${response}" | jq ".result.batchId")
  echo "batchId=${id}"
  if [ "${id}" -ne "1" ]; then
    exit 54
  fi
  echo "Tested removefrombatch."

  # getbatchdetails the default batch
  echo "Testing getbatchdetails..."
  response=$(curl -sd '{"batchId":1}' localhost:8888/getbatchdetails)
  echo "response=${response}"
  data2=$(echo "${response}" | jq ".result.nbOutputs")
  echo "nbOutputs=${data2}"
  if [ "${data2}" -ne "$((${data}-2))" ]; then
    exit 58
  fi
  echo "Tested getbatchdetails."














  # Create a batch
  echo "Testing createbatch..."
  response=$(curl -s -H 'Content-Type: application/json' -d '{"batchLabel":"testbatch","confTarget":32}' proxy:8888/createbatch)
  echo "response=${response}"
  id=$(echo "${response}" | jq -e ".result.batchId")
  if [ "$?" -ne "0" ]; then
    exit 60
  fi

  # List batches (should show at least default and testbatch batches)
  echo "Testing listbatches..."
  response=$(curl -s proxy:8888/listbatches)
  echo "response=${response}"
  id=$(echo "${response}" | jq '.result[] | select(.batchLabel == "testbatch") | .batchId')
  echo "batchId=${id}"
  if [ -z "${id}" ]; then
    exit 70
  fi
  echo "Tested listbatches."

  # getbatch the testbatch batch
  echo "Testing getbatch..."
  response=$(curl -sd '{"batchId":'${id}'}' localhost:8888/getbatch)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchLabel")
  echo "batchLabel=${data}"
  if [ "${data}" != "testbatch" ]; then
    exit 80
  fi

  response=$(curl -sd '{"batchLabel":"testbatch"}' localhost:8888/getbatch)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchId")
  echo "batchId=${data}"
  if [ "${data}" != "${id}" ]; then
    exit 90
  fi
  echo "Tested getbatch."

  # getbatchdetails the testbatch batch
  echo "Testing getbatchdetails..."
  response=$(curl -sd '{"batchLabel":"testbatch"}' localhost:8888/getbatchdetails)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchId")
  echo "batchId=${data}"
  if [ "${data}" != "${id}" ]; then
    exit 100
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 32
  fi

  response=$(curl -sd '{"batchId":'${id}'}' localhost:8888/getbatchdetails)
  echo "response=${response}"
  data=$(echo "${response}" | jq -r ".result.batchLabel")
  echo "batchLabel=${data}"
  if [ "${data}" != "testbatch" ]; then
    exit 35
  fi
  echo "${response}" | jq -e ".result.outputs"
  if [ "$?" -ne 0 ]; then
    exit 37
  fi
  echo "Tested getbatchdetails."

  # addtobatch to testbatch batch
  echo "Testing addtobatch..."
  address1=$(curl -s localhost:8888/getnewaddress | jq -r ".address")
  echo "address1=${address1}"
  response=$(curl -sd '{"batchId":'${id}',"outputLabel":"test001","address":"'${address1}'","amount":0.001,"webhookUrl":"'${url1}'/'${address1}'"}' localhost:8888/addtobatch)
  echo "response=${response}"
  data=$(echo "${response}" | jq ".result.batchId")
  echo "batchId=${data}"
  if [ "${data}" -ne "${id}" ]; then
    exit 40
  fi
  id2=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 42
  fi
  echo "outputId=${id2}"

  address2=$(curl -s localhost:8888/getnewaddress | jq -r ".address")
  echo "address2=${address2}"
  response=$(curl -sd '{"batchLabel":"testbatch","outputLabel":"test002","address":"'${address2}'","amount":0.002,"webhookUrl":"'${url2}'/'${address2}'"}' localhost:8888/addtobatch)
  echo "response=${response}"
  data=$(echo "${response}" | jq ".result.batchId")
  echo "batchId=${data}"
  if [ "${data}" -ne "${id}" ]; then
    exit 40
  fi
  id2=$(echo "${response}" | jq -e ".result.outputId")
  if [ "$?" -ne 0 ]; then
    exit 42
  fi
  echo "outputId=${id2}"
  echo "Tested addtobatch."

  # batchspend testbatch batch
  echo "Testing batchspend..."
  response=$(curl -sd '{"batchLabel":"testbatch"}' localhost:8888/batchspend)
  echo "response=${response}"
  data2=$(echo "${response}" | jq -e ".result.txid")
  if [ "$?" -ne 0 ]; then
    exit 44
  fi
  echo "txid=${data2}"
  data=$(echo "${response}" | jq ".result.outputs | length")
  if [ "${data}" -ne "2" ]; then
    exit 42
  fi
  echo "Tested batchspend."

  # getbatchdetails the testbatch batch
  echo "Testing getbatchdetails..."
  echo "txid=${data2}"
  response=$(curl -sd '{"batchLabel":"testbatch","txid":'${data2}'}' localhost:8888/getbatchdetails)
  echo "response=${response}"
  data=$(echo "${response}" | jq ".result.nbOutputs")
  echo "nbOutputs=${data}"
  if [ "${data}" -ne "2" ]; then
    exit 42
  fi
  echo "Tested getbatchdetails."

  # List batches
  # Add to batch
  # List batches
  # Remove from batch
  # List batches
}

wait_for_callbacks() {
  nc -vlp1111 -e ./tests-cb.sh &
  nc -vlp1112 -e ./tests-cb.sh &
}

wait_for_callbacks
testbatching
wait
