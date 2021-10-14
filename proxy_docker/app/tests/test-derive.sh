#!/bin/sh

test_derive() {
  local address
  local address1
  local address2
  local address3
  local response
  local transaction

  # deriveindex
  # (GET) http://proxy:8888/deriveindex/25-30
  # {"addresses":[{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}

  echo "Testing deriveindex..."
  response=$(curl -s proxy:8888/deriveindex/25-30)
  echo "response=${response}"
  local nbaddr=$(echo "${response}" | jq ".addresses | length")
  if [ "${nbaddr}" -ne "6" ]; then
    exit 130
  fi
  address=$(echo "${response}" | jq ".addresses[2].address" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 140
  fi
  echo "Tested deriveindex."

  # derivepubpath
  # (GET) http://proxy:8888/derivepubpath
  # BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
  # {"addresses":[{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}

  echo "Testing derivepubpath..."
  response=$(curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" proxy:8888/derivepubpath)
  echo "response=${response}"
  local nbaddr=$(echo "${response}" | jq ".addresses | length")
  if [ "${nbaddr}" -ne "6" ]; then
    exit 150
  fi
  address=$(echo "${response}" | jq ".addresses[2].address" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 160
  fi
  echo "Tested derivepubpath."

  # deriveindex_bitcoind
  # (GET) http://proxy:8888/deriveindex_bitcoind/25-30
  # ["2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8","2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV","2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP","2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6","2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH","2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"]

  echo "Testing deriveindex_bitcoind..."
  response=$(curl -s proxy:8888/deriveindex_bitcoind/25-30)
  echo "response=${response}"
  local nbaddr=$(echo "${response}" | jq ". | length")
  if [ "${nbaddr}" -ne "6" ]; then
    exit 130
  fi
  address=$(echo "${response}" | jq ".[2]" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 140
  fi
  echo "Tested deriveindex_bitcoind."

  # derivepubpath_bitcoind
  # (GET) http://proxy:8888/derivepubpath_bitcoind
  # BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
  # ["2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8","2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV","2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP","2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6","2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH","2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"]

  echo "Testing derivepubpath_bitcoind..."
  response=$(curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" proxy:8888/derivepubpath_bitcoind)
  echo "response=${response}"
  local nbaddr=$(echo "${response}" | jq ". | length")
  if [ "${nbaddr}" -ne "6" ]; then
    exit 150
  fi
  address=$(echo "${response}" | jq ".[2]" | tr -d '\"')
  if [ "${address}" != "2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP" ]; then
    exit 160
  fi
  echo "Tested derivepubpath_bitcoind."

  # deriveindex_bitcoind and derivepubpath_bitcoind faster derivation?
  echo -e "\nDeriving 500 addresses with derivepubpath (Pycoin)..."
  time curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/0-499\"}" proxy:8888/derivepubpath  > /dev/null

  echo -e "\nDeriving 500 addresses with derivepubpath_bitcoind (Bitcoin Core)..."
  time curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/0-499\"}" proxy:8888/derivepubpath_bitcoind  > /dev/null

  # Deriving 500 addresses with derivepubpath (pycoin)...
  # real	0m 18.15s
  # user	0m 0.00s
  # sys	0m 0.00s
  # 
  # Deriving 500 addresses with derivepubpath_bitcoind (Bitcoin Core)...
  # real	0m 0.64s
  # user	0m 0.00s
  # sys	0m 0.00s

}

apk add curl jq

test_derive
