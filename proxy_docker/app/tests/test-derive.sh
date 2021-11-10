#!/bin/bash

. ./colors.sh

# You need jq installed for these tests to run correctly

# This will test:
#
# - deriveindex
# - derivepubpath
# - deriveindex_bitcoind
# - derivepubpath_bitcoind
#
# ...and it will compare performance between Pycoin et Bitcoin Core's address derivations...
#

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -it --name test-derive --network=cyphernodenet alpine
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  docker stop test-derive
}

exec_in_test_container() {
  docker exec -it test-derive "$@"
}

tests_derive() {
  local address
  local address1
  local address2
  local address3
  local response
  local transaction

  trace 1 "\n\n[tests_derive] ${BCyan}Let's test the derivation features!...${Color_Off}\n"

  # deriveindex
  # (GET) http://proxy:8888/deriveindex/25-30
  # {"addresses":[{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}

  trace 2 "\n\n[tests_derive] ${BCyan}Testing deriveindex...${Color_Off}\n"
  response=$(exec_in_test_container curl -s proxy:8888/deriveindex/25-30)
  trace 3 "[tests_derive] response=${response}"
  local nbaddr=$(echo "${response}" | jq ".addresses | length")
  trace 3 "[tests_derive] nbaddr=${nbaddr}"
  if [ "${nbaddr}" -ne "6" ]; then
    exit 130
  fi
  address=$(echo "${response}" | jq ".addresses[2].address" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 140
  fi
  trace 2 "\n\n[tests_derive] ${BCyan}Tested deriveindex.${Color_Off}\n"

  # derivepubpath
  # (GET) http://proxy:8888/derivepubpath
  # BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
  # {"addresses":[{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}

  trace 2 "\n\n[tests_derive] ${BCyan}Testing derivepubpath...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" proxy:8888/derivepubpath)
  trace 3 "[tests_derive] response=${response}"
  local nbaddr=$(echo "${response}" | jq ".addresses | length")
  if [ "${nbaddr}" -ne "6" ]; then
    exit 150
  fi
  address=$(echo "${response}" | jq ".addresses[2].address" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 160
  fi
  trace 2 "\n\n[tests_derive] ${BCyan}Tested derivepubpath.${Color_Off}\n"

  # deriveindex_bitcoind
  # (GET) http://proxy:8888/deriveindex_bitcoind/25-30
  # ["2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8","2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV","2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP","2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6","2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH","2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"]

  trace 2 "\n\n[tests_derive] ${BCyan}Testing deriveindex_bitcoind...${Color_Off}\n"
  response=$(exec_in_test_container curl -s proxy:8888/deriveindex_bitcoind/25-30)
  trace 3 "[tests_derive] response=${response}"
  local nbaddr=$(echo "${response}" | jq ". | length")
  if [ "${nbaddr}" -ne "6" ]; then
    exit 130
  fi
  address=$(echo "${response}" | jq ".[2]" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 140
  fi
  trace 2 "\n\n[tests_derive] ${BCyan}Tested deriveindex_bitcoind.${Color_Off}\n"

  # derivepubpath_bitcoind
  # (GET) http://proxy:8888/derivepubpath_bitcoind
  # BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
  # ["2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8","2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV","2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP","2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6","2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH","2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"]

  trace 2 "\n\n[tests_derive] ${BCyan}Testing derivepubpath_bitcoind...${Color_Off}\n"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" proxy:8888/derivepubpath_bitcoind)
  trace 3 "[tests_derive] response=${response}"
  local nbaddr=$(echo "${response}" | jq ". | length")
  if [ "${nbaddr}" -ne "6" ]; then
    exit 150
  fi
  address=$(echo "${response}" | jq ".[2]" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 160
  fi
  trace 2 "\n\n[tests_derive] ${BCyan}Tested derivepubpath_bitcoind.${Color_Off}\n"

  # deriveindex_bitcoind and derivepubpath_bitcoind faster derivation?
  trace 2 "\n\n[tests_derive] ${BCyan}Deriving 500 addresses with derivepubpath (Pycoin)...${Color_Off}\n"
  exec_in_test_container sh -c 'time curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/0-499\"}" proxy:8888/derivepubpath > /dev/null'

  trace 2 "\n\n[tests_derive] ${BCyan}Deriving 500 addresses with derivepubpath_bitcoind (Bitcoin Core)...${Color_Off}\n"
  exec_in_test_container sh -c 'time curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/0-499\"}" proxy:8888/derivepubpath_bitcoind > /dev/null'

  # Deriving 500 addresses with derivepubpath (pycoin)...
  # real	0m 18.15s
  # user	0m 0.00s
  # sys	0m 0.00s
  # 
  # Deriving 500 addresses with derivepubpath_bitcoind (Bitcoin Core)...
  # real	0m 0.64s
  # user	0m 0.00s
  # sys	0m 0.00s

  trace 1 "\n\n[tests_derive] ${On_IGreen}${BBlack} ALL GOOD!  Yayyyy!                                           ${Color_Off}\n"

}

TRACING=3

stop_test_container
start_test_container

trace 1 "\n\n[test-derive] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container apk add --update curl

tests_derive

trace 1 "\n\n[test-derive] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[test-derive] ${BCyan}See ya!${Color_Off}\n"
