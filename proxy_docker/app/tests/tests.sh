#!/bin/bash
DIR="$( dirname -- "${BASH_SOURCE[0]}"; )"; 
. $DIR/colors.sh

# This should be run in regtest

# This will test:
#
# - getbestblockhash
# - getbestblockinfo
# - getblockinfo
# - getnewaddress
# - getbalance
# - deriveindex
# - derivepubpath
# - spend
# - gettransaction
# - gettxoutproof
# - generatetoaddress
# - ln_getinfo
# - ln_newaddr
#
#
trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -t --name tests-proxy --network=cyphernodenet alpine:3.15.4
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop test-derive
  local containers=$(docker ps -q -f "name=tests-proxy")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec tests-proxy "$@"
}

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

  print_title "Testing getbestblockhash..."
  response=$(exec_in_test_container curl -s proxy:8888/getbestblockhash)
  echo "response=${response}"
  local blockhash=$(echo ${response} | jq ".result" | tr -d '\"')
  echo "blockhash=${blockhash}"
  if [ -z "${blockhash}" ]; then
    exit 2
  fi
  echo "Tested getbestblockhash."

  # getbestblockinfo
  # exec_in_test_container curl (GET) http://proxy:8888/getbestblockinfo

  print_title "Testing getbestblockinfo..."
  response=$(exec_in_test_container curl -s proxy:8888/getbestblockinfo)
  echo "response=${response}"
  local blockhash2=$(echo ${response} | jq ".result.hash" | tr -d '\"')
  echo "blockhash2=${blockhash2}"
  if [ "${blockhash2}" != "${blockhash}" ]; then
    exit 4
  fi
  echo "Tested getbestblockinfo."

  # getblockinfo
  # (GET) http://proxy:8888/getblockinfo/000000006f82a384c208ecfa04d05beea02d420f3f398ddda5c7f900de5718ea

  print_title "Testing getblockinfo..."
  response=$(exec_in_test_container curl -s proxy:8888/getblockinfo/${blockhash})
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

  print_title "Testing getnewaddress..."
  response=$(exec_in_test_container curl -s proxy:8888/getnewaddress)
  echo "response=${response}"
  address1=$(echo ${response} | jq ".address" | tr -d '\"')
  echo "address1=${address1}"
  if [ -z "${address1}" ]; then
    exit 10
  fi
  address2=$(exec_in_test_container curl -s proxy:8888/getnewaddress | jq ".address" | tr -d '\"')
  echo "address2=${address2}"
  echo "Tested getnewaddress."

  # getbalance
  # (GET) http://proxy:8888/getbalance

  print_title "Testing getbalance..."
  response=$(exec_in_test_container curl -s proxy:8888/getbalance)
  echo "response=${response}"
  local balance=$(echo ${response} | jq ".balance")
  echo "balance=${balance}"
  if [ -z "${balance}" ]; then
    exit 12
  fi
  echo "Tested getbalance."

  
  # deriveindex
  # (GET) http://proxy:8888/deriveindex/25-30
  # {"addresses":[{"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},{"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},{"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},{"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},{"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},{"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}]}


  print_title "Testing deriveindex..."
  response=$(exec_in_test_container curl -s proxy:8888/deriveindex/25-30)
  echo "response=${response}"
  local nbaddr=$(echo "${response}" | jq ".addresses | length")
  echo "Length: [$nbaddr]"
  if [ "${nbaddr}" -ne "6" ]; then
    echo -e $Red;
    echo -e "In setup, make sure you set your default xpub key to$BBlue upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb$Red";
    echo -e "and default derivation to$BBlue 0/n";
    echo -e $Color_Off
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

  print_title "Testing derivepubpath..."
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" proxy:8888/derivepubpath)
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

  print_title "Testing spend"
  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "{\"address\":\"${address1}\",\"amount\":0.00001}" proxy:8888/spend)
  echo "response=${response}"
  
  echo
  echo "Mining a block"
  echo
  mine

  echo "Tested spend, conf and callbacks."


  # gettransaction
  # (GET) http://proxy:8888/gettransaction/af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648

  print_title "Testing gettransaction..."
  transaction=$(echo "${response}" | jq -r ".txid")
  response=$(exec_in_test_container curl -s proxy:8888/gettransaction/${transaction})
  echo "response=${response}"
  local txid=$(echo ${response} | jq ".result.txid" | tr -d '\"')
  local blockhash=$(echo ${response} | jq ".result.blockhash" | tr -d '\"')

  echo "txid=${txid}"
  if [ "${txid}" != "${transaction}" ]; then
    exit 8
  fi
  echo "Tested gettransaction."

  print_title "Testing bitcoin_generatetoaddress..."

  response=$(exec_in_test_container curl -s proxy:8888/getnewaddress)
  echo "response=${response}"
  local addresstomine=$(echo ${response} | jq ".address" | tr -d '\"')
  echo "addresstomine=${addresstomine}"
  if [ -z "${addresstomine}" ]; then
    exit 11
  fi

  print_title "Testing [exec_in_test_container curl -H \"Content-Type: application/json\" -d \"{\"nbblocks\":1,\"address\":\"${addresstomine}\",\"maxtries\":123}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(exec_in_test_container curl -H "Content-Type: application/json" -d "{\"nbblocks\":1,\"address\":\"${addresstomine}\",\"maxtries\":1}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress response=${response}"
  echo "bitcoin_generatetoaddress response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 12
  fi

  print_title "Testing [exec_in_test_container curl -H \"Content-Type: application/json\" -d \"{\"nbblocks\":1,\"address\":\"${addresstomine}\"}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(exec_in_test_container curl -H "Content-Type: application/json" -d "{\"nbblocks\":1,\"address\":\"${addresstomine}\"}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress (without maxtries) response=${response}"
  echo "bitcoin_generatetoaddress (without maxtries) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  print_title "Testing [exec_in_test_container curl -H \"Content-Type: application/json\" -d \"{\"nbblocks\":2}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(exec_in_test_container curl -H "Content-Type: application/json" -d "{\"nbblocks\":2}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress using (2, nil, nil) response=${response}"
  echo "bitcoin_generatetoaddress using (2, nil, nil) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  print_title "Testing [exec_in_test_container curl -H \"Content-Type: application/json\" -d \"{}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(exec_in_test_container curl -H "Content-Type: application/json" -d "{}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress using values (default, default, default) response=${response}"
  echo "bitcoin_generatetoaddress using values (default, default, default) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  print_title "Testing [exec_in_test_container curl -H \"Content-Type: application/json\" -d \"{\"address\":\"${addresstomine}\"}\" proxy:8888/bitcoin_generatetoaddress]"
  response=$(exec_in_test_container curl -H "Content-Type: application/json" -d "{\"address\":\"${addresstomine}\"}" proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress using values (default, address, default) response=${response}"
  echo "bitcoin_generatetoaddress using values (default, address, default) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 13
  fi

  print_title "Testing GET [exec_in_test_container curl proxy:8888/bitcoin_generatetoaddress]"
  response=$(exec_in_test_container curl proxy:8888/bitcoin_generatetoaddress)

  echo "bitcoin_generatetoaddress GET using values (default, default, default) response=${response}"
  echo "bitcoin_generatetoaddress GET using values (default, default, default) response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 14
  fi

  echo "Tested bitcoin_generatetoaddress."

  print_title "Testing gettxoutproof..."
  transaction=$(echo {\"txids\":\"[\\\"${txid}\\\"]\"})

  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "${transaction}" proxy:8888/bitcoin_gettxoutproof)

  echo "bitcoin_gettxoutproof response=${response}"
  echo "bitcoin_gettxoutproof response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 9
  fi

  print_title "Testing bitcoin_gettxoutproof txid+blockhash..."
#  transaction=$(echo {\"txids\":\"[\\\"${txid}\\\"]\",\"blockhash\":\"${blockhash}\"})
  transaction="{\"txids\":\"[\\\"${txid}\\\"]\",\"blockhash\":\"${blockhash}\"}"

  response=$(exec_in_test_container curl -s -H "Content-Type: application/json" -d "${transaction}" proxy:8888/bitcoin_gettxoutproof)

  echo "bitcoin_gettxoutproof response=${response}"
  echo "bitcoin_gettxoutproof response=$(echo ${response} | jq ".error")"

  if [ "$(echo ${response} | jq ".error")" != "null" ]; then
    exit 10
  fi

  echo "Tested bitcoin_gettxoutproof."

  # ln_getinfo
  # (GET) http://proxy:8888/ln_getinfo

  print_title "Testing ln_getinfo..."
  response=$(exec_in_test_container curl -s proxy:8888/ln_getinfo)
  echo "response=${response}"
  local port=$(echo ${response} | jq ".binding[] | select(.type == \"ipv4\") | .port")
  echo "port=${port}"
  if [ "${port}" != "9735" ]; then
    exit 170
  fi
  echo "Tested ln_getinfo."

  # ln_newaddr
  # (GET) http://proxy:8888/ln_newaddr

  print_title "Testing ln_newaddr..."
  response=$(exec_in_test_container curl -s proxy:8888/ln_newaddr)
  echo "response=${response}"
  address=$(echo ${response} | jq ".bech32")
  echo "address=${address}"
  if [ -z "${address}" ]; then
    exit 180
  fi
  echo "Tested ln_newaddr."

  # ln_create_invoice
  # POST http://proxy:8888/ln_create_invoice
  # BODY {"msatoshi":"10000","label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":"10"}

  #echo "Testing ln_create_invoice..."
  #response=$(exec_in_test_container curl -v -H "Content-Type: application/json" -d "{\"msatoshi\":10000,\"label\":\"koNCcrSvhX3dmyFhW\",\"description\":\"Bylls order #10649\",\"expiry\":10}" proxy:8888/ln_create_invoice)
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

  echo "response=exec_in_test_container curl -s proxy:8888/bitcoin_generatetoaddress"
  response=$(exec_in_test_container curl -s proxy:8888/bitcoin_generatetoaddress)

  echo "Mining one block response=[${response}]"

  if [ "$(echo "${response}" | jq ".error")" != "null" ]; then
    exit 12
  fi
}

print_title(){
  echo -e $BBlue; echo "$1"; echo -e $Color_Off
}

TRACING=3
returncode=0

stop_test_container
start_test_container

trace 1 "\n\n[tests] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container apk add --update curl jq

tests
returncode=$?

trace 1 "\n\n[tests] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[tests] ${BCyan}See ya! returncode=[${returncode}]${Color_Off}\n"

exit ${returncode}
