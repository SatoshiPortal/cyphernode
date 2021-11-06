#!/bin/sh

date

callbackservername=${1:-"tests-manage-missed"}
callbackserverport=${2:-"1111"}
callbackserverport2=${3:-"1112"}
callbackserverport3=${4:-"1113"}
callbackserverport4=${5:-"1114"}

docker run --rm -d --network cyphernodeappsnet --name ${callbackservername} alpine sh -c "nc -vlkp${callbackserverport} -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo 1>&2'"
docker exec -d ${callbackservername} sh -c "nc -vlkp${callbackserverport2} -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo 1>&2'"
docker exec -d ${callbackservername} sh -c "nc -vlkp${callbackserverport3} -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo 1>&2'"
docker exec -d ${callbackservername} sh -c "nc -vlkp${callbackserverport4} -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo 1>&2'"

