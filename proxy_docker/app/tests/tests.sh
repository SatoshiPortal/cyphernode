#!/bin/sh

# This should be run in regtest

# docker run -it --rm -it --name cn-tests --network=cyphernodenet -v "$PWD/tests.sh:/tests.sh" -v "$PWD/tests-cb.sh:/tests-cb.sh" alpine /tests.sh

# This will test:
#
# - getbestblockhash
# - getbestblockinfo
# - getblockinfo
# - getnewaddress
# - getbalance
# - watch and callbacks
# - getactivewatches
# - unwatch
# - deriveindex
# - derivepubpath
# - spend
# - gettransaction
# - ln_getinfo
# - ln_newaddr
#
#

tests()
{
  local address
  local address1
  local address2
  local address3
  local response
  local transaction

  # getbestblockhash
  # (GET) http://proxy:8888/getbestblockhash

  echo "Testing getbestblockhash..."
  response=$(curl -s proxy:8888/getbestblockhash)
  echo "response=${response}"
  local blockhash=$(echo ${response} | jq ".result" | tr -d '\"')
  echo "blockhash=${blockhash}"
  if [ -z "${blockhash}" ]; then
    exit 2
  fi
  echo "Tested getbestblockhash."

  # getbestblockinfo
  # curl (GET) http://proxy:8888/getbestblockinfo

  echo "Testing getbestblockinfo..."
  response=$(curl -s proxy:8888/getbestblockinfo)
  echo "response=${response}"
  local blockhash2=$(echo ${response} | jq ".result.hash" | tr -d '\"')
  echo "blockhash2=${blockhash2}"
  if [ "${blockhash2}" != "${blockhash}" ]; then
    exit 4
  fi
  echo "Tested getbestblockinfo."

  # getblockinfo
  # (GET) http://proxy:8888/getblockinfo/000000006f82a384c208ecfa04d05beea02d420f3f398ddda5c7f900de5718ea

  echo "Testing getblockinfo..."
  response=$(curl -s proxy:8888/getblockinfo/${blockhash})
  echo "response=${response}"
  blockhash2=$(echo ${response} | jq ".result.hash" | tr -d '\"')
  echo "blockhash2=${blockhash2}"
  if [ "${blockhash2}" != "${blockhash}" ]; then
    exit 6
  fi
  echo "Tested getblockinfo."

  # getnewaddress
  # (GET) http://proxy:8888/getnewaddress
  # returns {"address":"2MuiUu8AyuByAGYRDAqqhdYxt8gXcsQ1Ymw"}

  echo "Testing getnewaddress..."
  response=$(curl -s proxy:8888/getnewaddress)
  echo "response=${response}"
  address1=$(echo ${response} | jq ".address" | tr -d '\"')
  echo "address1=${address1}"
  if [ -z "${address1}" ]; then
    exit 10
  fi
  address2=$(curl -s proxy:8888/getnewaddress | jq ".address" | tr -d '\"')
  echo "address2=${address2}"
  echo "Tested getnewaddress."

  # getbalance
  # (GET) http://proxy:8888/getbalance

  echo "Testing getbalance..."
  response=$(curl -s proxy:8888/getbalance)
  echo "response=${response}"
  local balance=$(echo ${response} | jq ".balance")
  echo "balance=${balance}"
  if [ -z "${balance}" ]; then
    exit 12
  fi
  echo "Tested getbalance."

  # watch
  # POST http://proxy:8888/watch
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.122.233:1111/callback0conf","confirmedCallbackURL":"192.168.122.233:1111/callback1conf"}

  echo "Testing watch..."
  local url1="$(hostname):1111/callback0conf"
  local url2="$(hostname):1111/callback1conf"
  echo "url1=${url1}"
  echo "url2=${url2}"
  response=$(curl -s -H "Content-Type: application/json" -d "{\"address\":\"${address1}\",\"unconfirmedCallbackURL\":\"${url1}\",\"confirmedCallbackURL\":\"${url2}\"}" proxy:8888/watch)
  echo "response=${response}"

  local id=$(echo "${response}" | jq ".id" | tr -d '\"')
  echo "id=${id}"
  local event=$(echo "${response}" | jq ".event" | tr -d '\"')
  echo "event=${event}"
  if [ "${event}" != "watch" ]; then
    exit 15
  fi
   address=$(echo "${response}" | jq ".address" | tr -d '\"')
  echo "address=${address}"
  if [ "${address}" != "${address1}" ]; then
    exit 20
  fi
  local imported=$(echo "${response}" | jq ".imported" | tr -d '\"')
  echo "imported=${imported}"
  if [ "${imported}" != "true" ]; then
    exit 30
  fi
  local inserted=$(echo "${response}" | jq ".inserted" | tr -d '\"')
  echo "inserted=${inserted}"
  if [ "${inserted}" != "true" ]; then
    exit 40
  fi
  local unconfirmedCallbackURL=$(echo "${response}" | jq ".unconfirmedCallbackURL" | tr -d '\"')
  echo "unconfirmedCallbackURL=${unconfirmedCallbackURL}"
  if [ "${unconfirmedCallbackURL}" != "${url1}" ]; then
    exit 60
  fi
  local confirmedCallbackURL=$(echo "${response}" | jq ".confirmedCallbackURL" | tr -d '\"')
  echo "confirmedCallbackURL=${confirmedCallbackURL}"
  if [ "${confirmedCallbackURL}" != "${url2}" ]; then
    exit 70
  fi

  # Let's watch another address just to be able to test unwatch later and test if found in getactivewatches
  response=$(curl -s -H "Content-Type: application/json" -d "{\"address\":\"${address2}\",\"unconfirmedCallbackURL\":\"${url1}2\",\"confirmedCallbackURL\":\"${url2}2\"}" proxy:8888/watch)
  echo "response=${response}"
  echo "Tested watch."

  # getactivewatches
  # (GET) http://proxy:8888/getactivewatches

  echo "Testing getactivewatches..."
  response=$(curl -s proxy:8888/getactivewatches)
  echo "response=${response}"
  response=$(echo ${response} | jq ".watches[]")
  echo "response=${response}"
  local id2=$(echo ${response} | jq "select(.address == \"${address1}\") | .id" | tr -d '\"')
  echo "id2=${id2}"
  if [ "${id2}" != "${id}" ]; then
    exit 80
  fi
  id2=$(echo ${response} | jq "select(.address == \"${address2}\") | .id" | tr -d '\"')
  echo "id2=${id2}"
  if [ -z "${id2}" ]; then
    exit 90
  fi
  echo "Tested getactivewatches."

  # unwatch
  # (GET) http://proxy:8888/unwatch/2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp

  echo "Testing unwatch..."
  response=$(curl -s proxy:8888/unwatch/${address2})
  echo "response=${response}"
  event=$(echo "${response}" | jq ".event" | tr -d '\"')
  echo "event=${event}"
  if [ "${event}" != "unwatch" ]; then
    exit 100
  fi
   address=$(echo "${response}" | jq ".address" | tr -d '\"')
  echo "address=${address}"
  if [ "${address}" != "${address2}" ]; then
    exit 110
  fi
  response=$(curl -s proxy:8888/getactivewatches)
  echo "response=${response}"
  response=$(echo "${response}" | jq ".watches[]")
  echo "response=${response}"
  id2=$(echo ${response} | jq "select(.address == \"${address2}\") | .id" | tr -d '\"')
  echo "id2=${id2}"
  if [ -n "${id2}" ]; then
    exit 120
  fi
  echo "Tested unwatch."

  # deriveindex
  # (GET) http://proxy:8888/deriveindex/25-30
  # {"addresses":[{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}

  echo "Testing deriveindex..."
  response=$(curl -v proxy:8888/deriveindex/25-30)
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
  response=$(curl -v -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" proxy:8888/derivepubpath)
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

  # spend
  # POST http://proxy:8888/spend
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}

  # By spending to a watched address, we will test the spending feature and trigger the confirmation to test
  # confirmations of watched addresses... Cleva!!!

  echo "Testing spend, conf and callbacks..."
  response=$(curl -v -H "Content-Type: application/json" -d "{\"address\":\"${address1}\",\"amount\":0.00001}" proxy:8888/spend)
  echo "response=${response}"
  echo
  echo "Mining a block in 2 secs"
  echo
  (sleep 2; mine) &

  wait_for_callbacks
  echo "Tested spend, conf and callbacks."


  # gettransaction
  # (GET) http://proxy:8888/gettransaction/af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648

  echo "Testing gettransaction..."
  transaction=$(echo "${response}" | jq -r ".txid")
  response=$(curl -s proxy:8888/gettransaction/${transaction})
  echo "response=${response}"
  local txid=$(echo ${response} | jq ".result.txid" | tr -d '\"')
  echo "txid=${txid}"
  if [ "${txid}" != "${transaction}" ]; then
    exit 8
  fi
  echo "Tested gettransaction."

  echo "Testing bitcoin_generatetoaddress..."

  response=$(curl -s proxy:8888/getnewaddress)
  echo "response=${response}"
  local addresstomine=$(echo ${response} | jq ".address" | tr -d '\"')
  echo "addresstomine=${addresstomine}"
  if [ -z "${addresstomine}" ]; then
    exit 11
  fi

  echo "Testing [curl -H \"Content-Type: application/json\" -d \"{\"nbblocks\":1,\"address\":\"${addresstomine}\",\"maxtries\":123}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(curl -H "Content-Type: application/json" -d "{\"nbblocks\":1,\"address\":\"${addresstomine}\",\"maxtries\":1}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress response=${response}"
  echo "bitcoin_generatetoaddress response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 12
  fi

  echo "Testing [curl -H \"Content-Type: application/json\" -d \"{\"nbblocks\":1,\"address\":\"${addresstomine}\"}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(curl -H "Content-Type: application/json" -d "{\"nbblocks\":1,\"address\":\"${addresstomine}\"}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress (without maxtries) response=${response}"
  echo "bitcoin_generatetoaddress (without maxtries) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  echo "Testing [curl -H \"Content-Type: application/json\" -d \"{\"nbblocks\":2}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(curl -H "Content-Type: application/json" -d "{\"nbblocks\":2}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress using (2, nil, nil) response=${response}"
  echo "bitcoin_generatetoaddress using (2, nil, nil) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  echo "Testing [curl -H \"Content-Type: application/json\" -d \"{}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(curl -H "Content-Type: application/json" -d "{}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress using values (default, default, default) response=${response}"
  echo "bitcoin_generatetoaddress using values (default, default, default) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  echo "Testing [curl -H \"Content-Type: application/json\" -d \"{\"address\":\"${addresstomine}\"}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(curl -H "Content-Type: application/json" -d "{\"address\":\"${addresstomine}\"}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress using values (default, address, default) response=${response}"
  echo "bitcoin_generatetoaddress using values (default, address, default) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  echo "Tested bitcoin_generatetoaddress."

  # addtobatch
  # POST http://proxy:8888/addtobatch
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}

  # By spending to a watched address, we will test the spending feature and trigger the confirmation to test
  # confirmations of watched addresses... Cleva!!!

#  echo "Testing addtobatch..."
#  response=$(curl -v -H "Content-Type: application/json" -d "{\"address\":\"${address1}\",\"amount\":0.00001}" proxy:8888/spend)
#  echo "response=${response}"
#  wait_for_callbacks
#  echo "Tested addtobatch  ."




  # conf
  # (GET) http://proxy:8888/conf/b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387

  # Let's trigger tx confirmation even if not confirmed.  Will be funny.  Should take care of
  # multiple confirmations of the same state.



  # executecallbacks
  # (GET) http://cyphernode::8080/executecallbacks

  #echo "GET /getbestblockinfo" | nc proxy:8888 - | sed -En "s/^(\{.*)/\1/p" | jq




  # spend
  # POST http://proxy:8888/spend
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}

  #curl -v -H "Content-Type: application/json" -d '{"address":"2MsWyaQ8APbnqasFpWopqUKqsdpiVY3EwLE","amount":0.0001}' proxy:8888/spend

  # ln_getinfo
  # (GET) http://proxy:8888/ln_getinfo

  echo "Testing ln_getinfo..."
  response=$(curl -s proxy:8888/ln_getinfo)
  echo "response=${response}"
  local port=$(echo ${response} | jq ".binding[] | select(.type == \"ipv4\") | .port")
  echo "port=${port}"
  if [ "${port}" != "9735" ]; then
    exit 170
  fi
  echo "Tested ln_getinfo."

  # ln_newaddr
  # (GET) http://proxy:8888/ln_newaddr

  echo "Testing ln_newaddr..."
  response=$(curl -s proxy:8888/ln_newaddr)
  echo "response=${response}"
  address=$(echo ${response} | jq ".address")
  echo "address=${address}"
  if [ -z "${address}" ]; then
    exit 180
  fi
  echo "Tested ln_newaddr."

  # ln_create_invoice
  # POST http://proxy:8888/ln_create_invoice
  # BODY {"msatoshi":"10000","label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":"10"}

  #echo "Testing ln_create_invoice..."
  #response=$(curl -v -H "Content-Type: application/json" -d "{\"msatoshi\":10000,\"label\":\"koNCcrSvhX3dmyFhW\",\"description\":\"Bylls order #10649\",\"expiry\":10}" proxy:8888/ln_create_invoice)
  #echo "response=${response}"

  #echo "Tested ln_create_invoice."

  # ln_pay


}

#
# Mines 1 block
#
mine(){
  local response
  
  echo "About to mine one block"

  echo "response=curl -H \"Content-Type: application/json\" -d \"{}\" proxy:8888/bitcoin_generatetoaddress"
  response=$(curl -H "Content-Type: application/json" -d "{}" proxy:8888/bitcoin_generatetoaddress)

  echo "Mining one block response=${response}"
  echo "Mining one block response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 12
  fi
}

wait_for_callbacks()
{
  nc -vlp1111 -e ./tests-cb.sh
  nc -vlp1111 -e ./tests-cb.sh
}

apk add curl jq

tests
