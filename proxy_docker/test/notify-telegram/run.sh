#!/bin/sh

NETWORK=cn-test-network
DATETIME=`date -u +"%FT%H%MZ"`
NOTIFIER_IMAGE=notifier-test
BROKER_IMAGE=eclipse-mosquitto:1.6-openssl
TEST_IMAGE=test-image

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

build_test_image()
{
  local image=$(docker image ls | grep $TEST_IMAGE );

  if [[ ! $image =~ $TEST_IMAGE ]]; then

  #/Users/philippelamy/werk/telegram/proxy_docker/test/notify-telegram/run.sh
    docker build -f Dockerfile-test-notify --no-cache -t $TEST_IMAGE ../..
  else
    echo "Test image found"
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


create_test_network
build_notifier
build_test_image

#Run broker
echo 'running broker'
docker run --cidfile=broker-id-file.cid -d --rm --network $NETWORK --name broker $BROKER_IMAGE

#Run Notifier
echo 'running notifier'
docker run --cidfile=notifier-id-file.cid --rm -d -p 1883:1883 -p 9001:9001 -v `pwd`/../cyphernode/logs:/cnlogs --network $NETWORK --env-file notifier-env.env --name notifier $NOTIFIER_IMAGE `id -u`:`id -g` ./startnotifier.sh

#Run tests
echo 'running tests'
docker run --cidfile=test-image-id-file.cid --rm -d -v `pwd`/../cyphernode/logs:/cnlogs --network $NETWORK --name test-image $TEST_IMAGE `id -u`:`id -g` ./test.sh

sleep 5
echo 'Stopping container'
docker stop `cat notifier-id-file.cid`
docker stop `cat broker-id-file.cid`
docker stop `cat test-image-id-file.cid`

rm -f *.cid

echo 'Removing network'
docker network rm $NETWORK


echo 'Removing image'
docker image rm $NOTIFIER_IMAGE
docker image rm $TEST_IMAGE
