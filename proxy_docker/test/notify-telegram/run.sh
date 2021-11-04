#!/bin/sh

NETWORK=cn-test-network
DATETIME=`date -u +"%FT%H%MZ"`
PROXY_IMAGE=api-proxy-docker-test
NOTIFIER_IMAGE=notifier-test
BROKER_IMAGE=eclipse-mosquitto:1.6-openssl

echo Setting up to test `pwd` on $DATETIME

create_test_network()
{
  local network=$(docker network ls | grep $NETWORK );

  if [[ ! $network =~ $NETWORK ]]; then
    docker network create $NETWORK
  else
    echo "Network found"
  fi    
} 

build_proxy()
{
  local image=$(docker image ls | grep $PROXY_IMAGE );

  if [[ ! $image =~ $PROXY_IMAGE ]]; then
    docker build -f ../../Dockerfile --no-cache -t $PROXY_IMAGE ../..
  else
    echo "Proxy image found"
  fi
}

build_notifier()
{
  local image=$(docker image ls | grep $NOTIFIER_IMAGE );

  if [[ ! $image =~ $NOTIFIER_IMAGE ]]; then
    docker build -f ../../../notifier_docker/Dockerfile --no-cache -t $NOTIFIER_IMAGE ../../../notifier_docker
  else
    echo "Notifier image found"
  fi
}

curl_it() {
  local returncode
  local response
  local webresponse=$(mktemp)

  local url=$(echo "${1}" | tr -d '"')
  # Decode data that base base64 encoded
  local data=$(echo "${2}" | base64 -d)

  if [ -n "${data}" ]; then
    rc=$(curl -o ${webresponse} -m 20 -w "%{http_code}" -H "Content-Type: application/json" -H "X-Forwarded-Proto: https" -d "${data}" -k ${url})
    returncode=$?
  else
    rc=$(curl -o ${webresponse} -m 20 -w "%{http_code}" -k ${url})
    returncode=$?
  fi

  if [ "${returncode}" -eq "0" ]; then
    response=$(cat ${webresponse} | base64 | tr -d '\n')
  else
    response=
  fi

  rm ${webresponse}

  # When curl is unable to connect, http_code is "000" which is not a valid JSON number
  [ "${rc}" -eq "0" ] && rc=0
  response="{\"curl_code\":${returncode},\"http_code\":${rc},\"body\":\"${response}\"}"

  echo "${response}"

  if [ "${returncode}" -eq "0" ]; then
    if [ "${rc}" -lt "400" ]; then
      return 0
    else
      return ${rc}
    fi
  else
    return ${returncode}
  fi
}



create_test_network
build_proxy
build_notifier

#Run proxy
docker run --rm -p 8888:8888 --cidfile=proxy-id-file.cid -d -v `pwd`/../cyphernode/logs:/cnlogs -v `pwd`/../cyphernode/proxy:/proxy/db --network $NETWORK --name cn-proxy-test --env-file ./env.properties $PROXY_IMAGE `id -u`:`id -g` ./startproxy.sh

#Run broker
docker run --cidfile=broker-id-file.cid -d --rm --network $NETWORK --name broker $BROKER_IMAGE

#Run Notifier
docker run --cidfile=notifier-id-file.cid --rm -d -p 1883:1883 -p 9001:9001 -v `pwd`/../cyphernode/logs:/cnlogs --network $NETWORK --env-file ./env-notifier-test.properties --name notifier $NOTIFIER_IMAGE `id -u`:`id -g` ./startnotifier.sh

##################################################
# Run some tests
##################################################

echo -n "  Testing helloworld... "
curl_it "http://localhost:8888/helloworld"
if [ "$?" -ne "0" ]; then
  echo ">>>>> Failed"
fi

echo -n "  Testing notify_telegram... "

curl_it "http://localhost:8888/notify_telegram" "$(echo {\"text\":\"Proxy text in POST data ${DATETIME}\"} | base64)"

if [ "$?" -ne "0" ]; then
  echo ">>>>> Failed"
fi

echo 'Stopping container'
docker stop `cat proxy-id-file.cid`
docker stop `cat notifier-id-file.cid`
docker stop `cat broker-id-file.cid`

rm -f *.cid

echo 'Removing network'
docker network rm $NETWORK


echo 'Removing image'
docker image rm $PROXY_IMAGE
docker image rm $BROKER_IMAGE
docker image rm $NOTIFIER_IMAGE

#echo "HTML Test and Report information for this run can be seen here: `pwd`/results/test-results-$DATETIME/index.html"
