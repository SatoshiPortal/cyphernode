#!/bin/bash

. ./colors.sh
. ./mine.sh

# This needs to be run in regtest
# You need jq installed for these tests to run correctly

# This will test:
#
# - watchxpub
# - get_unused_addresses_by_watchlabel
# - derivepubpath_bitcoind
# - getactivexpubwatches
# - getactivewatchesbyxpub
# - getactivewatchesbylabel
# - spend
# - get_txns_by_watchlabel
# - unwatchxpubbyxpub
# - unwatchxpubbylabel
#

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -e "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

start_test_container() {
  docker run -d --rm -t --name tests-watch-pub32 --network=cyphernodenet alpine
}

stop_test_container() {
  trace 1 "\n\n[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  # docker stop tests-watch-pub32
  # docker stop tests-watch-pub32-cb
  local containers=$(docker ps -q -f "name=tests-watch-pub32")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  docker exec -it tests-watch-pub32 "$@"
}

test_watch_pub32() {
  # Watch an xpub
  # 1. Call watchxpub with xpub1 label1 with url1 as callback
  # 2. Call watchxpub with xpub2 label2 with url2 as callback

  # 3. Call get_unused_addresses_by_watchlabel with label1 /10, take last as address1, save index1
  # 4. Call get_unused_addresses_by_watchlabel with label2 /10, take last as address2, save index2

  # 5. Call derivepubpath_bitcoind with xpub1 path 0/index1, compare with address1
  # 6. Call derivepubpath_bitcoind with xpub2 path 0/index2, compare with address2

  # 7. Call getactivexpubwatches
  # 8. Call getactivewatchesbyxpub with xpub1, compare index1'th address with address1
  # 9. Call getactivewatchesbyxpub with xpub2, compare index2'th address with address2
  # 10. Call getactivewatchesbylabel with label1, compare index1'th address with address1
  # 11. Call getactivewatchesbylabel with label2, compare index2'th address with address2

  # 12. Send coins to address1, wait for callback
  # 13. Send coins to address2, wait for callback

  # 14. Call get_txns_by_watchlabel for label1, search sent tx
  # 15. Call get_txns_by_watchlabel for label2, search sent tx

  # 16. Call get_unused_addresses_by_watchlabel with label1 /10, check address1 is NOT there
  # 17. Call get_unused_addresses_by_watchlabel with label2 /10, check address2 is NOT there

  # 18. Call getactivexpubwatches
  # 19. Call getactivewatchesbyxpub with xpub1, last n should be 10 more (index1 + 100)
  # 20. Call getactivewatchesbyxpub with xpub2, last n should be 10 more (index2 + 100)

  # 21. Call unwatchxpubbyxpub with xpub1
  # 22. Call unwatchxpubbylabel with label2

  # 23. Call getactivewatchesbyxpub with xpub1, should be empty
  # 24. Call getactivewatchesbyxpub with xpub2, should be empty

  local xpub1="upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb"
  local xpub2="tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk"
  local label1="label$RANDOM"
  local label2="label$RANDOM"
  local path1="0/n"
  local path2="0/n"
  local path_a1
  local path_a2
  local callbackurl0conf1="http://${callbackservername}:1111/callbackurl0conf1"
  local callbackurl1conf1="http://${callbackservername}:1112/callbackurl1conf1"
  local callbackurl0conf2="http://${callbackservername}:1113/callbackurl0conf2"
  local callbackurl1conf2="http://${callbackservername}:1114/callbackurl1conf2"
  local address
  local address1
  local address2
  local last_imported_n1
  local last_imported_n2
  local last_imported_n1_x
  local last_imported_n2_x
  local index
  local index1
  local index2
  local txid
  local txid1
  local txid2
  local data
  local response

  trace 1 "\n\n[test_watch_pub32] ${BCyan}Let's test \"watch by xpub\" features!...${Color_Off}\n"

  # 1. Call watchxpub with xpub1 label1 with url1 as callback
  trace 2 "\n\n[test_watch_pub32] ${BCyan}1. watchxpub 1...${Color_Off}\n"
  data='{"label":"'${label1}'","pub32":"'${xpub1}'","path":"'${path1}'","nstart":0,"unconfirmedCallbackURL":"'${callbackurl0conf1}'","confirmedCallbackURL":"'${callbackurl1conf1}'"}'
  trace 3 "[test_watch_pub32] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watchxpub)
  trace 3 "[test_watch_pub32] response=${response}"
  data=$(echo "${response}" | jq -re ".error")
  if [ "${?}" -eq "0" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 1. watchxpub 1 failed: ${data}!                                           ${Color_Off}\n"
    return 10
  fi

  # 2. Call watchxpub with xpub2 label2 with url2 as callback
  trace 2 "\n\n[test_watch_pub32] ${BCyan}2. watchxpub 2...${Color_Off}\n"
  data='{"label":"'${label2}'","pub32":"'${xpub2}'","path":"'${path2}'","nstart":0,"unconfirmedCallbackURL":"'${callbackurl0conf2}'","confirmedCallbackURL":"'${callbackurl1conf2}'"}'
  trace 3 "[test_watch_pub32] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/watchxpub)
  trace 3 "[test_watch_pub32] response=${response}"
  data=$(echo "${response}" | jq -re ".label")
  if [ "${label2}" != "${data}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 2. watchxpub 2 failed!                                           ${Color_Off}\n"
    return 20
  fi


  # 3. Call get_unused_addresses_by_watchlabel with label1 /10, take last as address1, save index1
  trace 2 "\n\n[test_watch_pub32] ${BCyan}3. Call get_unused_addresses_by_watchlabel with label1 /10...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/get_unused_addresses_by_watchlabel/${label1}/10)
  trace 3 "[test_watch_pub32] response=${response}"
  address1=$(echo "${response}" | jq -r ".label_unused_addresses[9] | .address")
  trace 3 "[test_watch_pub32] address1=${address1}"
  index1=$(echo "${response}" | jq -r ".label_unused_addresses[9] | .address_pub32_index")
  trace 3 "[test_watch_pub32] index1=${index1}"
  if [ "${address1}" = "null" ] || [ "${index1}" = "null" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 3. Call get_unused_addresses_by_watchlabel with label1 /10!                                           ${Color_Off}\n"
    return 87
  fi

  # 4. Call get_unused_addresses_by_watchlabel with label2 /10, take last as address2, save index2
  trace 2 "\n\n[test_watch_pub32] ${BCyan}4. Call get_unused_addresses_by_watchlabel with label2 /10...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/get_unused_addresses_by_watchlabel/${label2}/10)
  trace 3 "[test_watch_pub32] response=${response}"
  address2=$(echo "${response}" | jq -r ".label_unused_addresses[9] | .address")
  trace 3 "[test_watch_pub32] address2=${address2}"
  index2=$(echo "${response}" | jq -r ".label_unused_addresses[9] | .address_pub32_index")
  trace 3 "[test_watch_pub32] index2=${index2}"
  if [ "${address2}" = "null" ] || [ "${index2}" = "null" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 4. Call get_unused_addresses_by_watchlabel with label2 /10!                                           ${Color_Off}\n"
    return 87
  fi


  # 5. Call derivepubpath_bitcoind with xpub1 path 0/index1, compare with address1
  trace 2 "\n\n[test_watch_pub32] ${BCyan}5. Call derivepubpath_bitcoind with xpub1 path 0/index1...${Color_Off}\n"
  path_a1=$(echo "${path1}" | sed -En "s/n/${index1}/p")
  data='{"pub32":"'${xpub1}'","path":"'${path_a1}'"}'
  trace 3 "[test_watch_pub32] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/derivepubpath_bitcoind)
  trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".[0]")
  trace 3 "[test_watch_pub32] address=${address}"
  if [ "${address}" != "${address1}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 5. Call derivepubpath_bitcoind with xpub1 path 0/index1!                                           ${Color_Off}\n"
    return 30
  fi

  # 6. Call derivepubpath_bitcoind with xpub2 path 0/index2, compare with address2
  trace 2 "\n\n[test_watch_pub32] ${BCyan}6. Call derivepubpath_bitcoind with xpub2 path 0/index2...${Color_Off}\n"
  path_a2=$(echo "${path2}" | sed -En "s/n/${index2}/p")
  data='{"pub32":"'${xpub2}'","path":"'${path_a2}'"}'
  trace 3 "[test_watch_pub32] data=${data}"
  response=$(exec_in_test_container curl -d "${data}" proxy:8888/derivepubpath_bitcoind)
  trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".[0]")
  trace 3 "[test_watch_pub32] address=${address}"
  if [ "${address}" != "${address2}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 6. Call derivepubpath_bitcoind with xpub2 path 0/index2!                                           ${Color_Off}\n"
    return 30
  fi


  # 7. Call getactivexpubwatches
  trace 2 "\n\n[test_watch_pub32] ${BCyan}7. getactivexpubwatches...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivexpubwatches)
  trace 3 "[test_watch_pub32] response=${response}"
  last_imported_n1=$(echo "${response}" | jq -r ".watches | map(select(.pub32 == \"${xpub1}\"))[0] | .last_imported_n")
  trace 3 "[test_watch_pub32] last_imported_n1=${last_imported_n1}"
  last_imported_n2=$(echo "${response}" | jq -r ".watches | map(select(.pub32 == \"${xpub2}\"))[0] | .last_imported_n")
  trace 3 "[test_watch_pub32] last_imported_n2=${last_imported_n2}"
  if [ "${last_imported_n1}" -ne "100" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 7. \"${last_imported_n1}\" -ne \"100\"!                                           ${Color_Off}\n"
    return 50
  fi
  if [ "${last_imported_n2}" -ne "100" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 7. \"${last_imported_n2}\" -ne \"100\"!                                           ${Color_Off}\n"
    return 55
  fi

  # 8. Call getactivewatchesbyxpub with xpub1, compare index1'th address with address1
  trace 2 "\n\n[test_watch_pub32] ${BCyan}8. Call getactivewatchesbyxpub with xpub1...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbyxpub/${xpub1})
  # trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".watches | map(select(.pub32_index == ${index1}))[0] | .address")
  trace 3 "[test_watch_pub32] ${index1}th address=${address}"
  if [ "${address}" != "${address1}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 8. Call getactivewatchesbyxpub with xpub1: \"${address}\" != \"${address1}\"!                                           ${Color_Off}\n"
    return 60
  fi
  # Check if last_imported_n1 exists in watched list
  index=$(echo "${response}" | jq -r "[.watches[].pub32_index] | index(${last_imported_n1})")
  trace 3 "[test_watch_pub32] index=${index}"
  if [ "${index}" != "100" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 8. Call getactivewatchesbyxpub with xpub1: \"${index}\" != \"100\"!                                           ${Color_Off}\n"
    return 65
  fi

  # 9. Call getactivewatchesbyxpub with xpub2, compare index2'th address with address2
  trace 2 "\n\n[test_watch_pub32] ${BCyan}9. Call getactivewatchesbyxpub with xpub2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbyxpub/${xpub2})
  # trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".watches | map(select(.pub32_index == ${index2}))[0] | .address")
  trace 3 "[test_watch_pub32] ${index2}th address=${address}"
  if [ "${address}" != "${address2}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 9. Call getactivewatchesbyxpub with xpub2: \"${address}\" != \"${address2}\"!                                           ${Color_Off}\n"
    return 60
  fi
  # Check if last_imported_n1 exists in watched list
  index=$(echo "${response}" | jq -r "[.watches[].pub32_index] | index(${last_imported_n2})")
  trace 3 "[test_watch_pub32] index=${index}"
  if [ "${index}" != "100" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 9. Call getactivewatchesbyxpub with xpub2: \"${index}\" != \"100\"!                                           ${Color_Off}\n"
    return 65
  fi

  # 10. Call getactivewatchesbylabel with label1, compare index1'th address with address1
  trace 2 "\n\n[test_watch_pub32] ${BCyan}10. Call getactivewatchesbylabel with label1...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbylabel/${label1})
  # trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".watches | map(select(.pub32_index == ${index1}))[0] | .address")
  trace 3 "[test_watch_pub32] ${index1}th address=${address}"
  if [ "${address}" != "${address1}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 10. Call getactivewatchesbylabel with label1: \"${address}\" != \"${address1}\"!                                           ${Color_Off}\n"
    return 80
  fi

  # 11. Call getactivewatchesbylabel with label2, compare index2'th address with address2
  trace 2 "\n\n[test_watch_pub32] ${BCyan}11. Call getactivewatchesbylabel with label2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbylabel/${label2})
  # trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".watches | map(select(.pub32_index == ${index2}))[0] | .address")
  trace 3 "[test_watch_pub32] ${index2}th address=${address}"
  if [ "${address}" != "${address2}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 11. Call getactivewatchesbylabel with label2: \"${address}\" != \"${address2}\"!                                           ${Color_Off}\n"
    return 80
  fi


  # 12. Send coins to address1, wait for callback
  trace 2 "\n\n[test_watch_pub32] ${BCyan}12. Send coins to address1...${Color_Off}\n"
  start_callback_server 1111
  # Let's use the bitcoin node directly to better simulate an external spend
  txid1=$(docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address1} 0.0001 | tr -d "\r\n")
#  txid1=$(exec_in_test_container curl -d '{"address":"'${address1}'","amount":0.001}' proxy:8888/spend | jq -r ".txid")
  trace 3 "[test_watch_pub32] txid1=${txid1}"
  trace 3 "[test_watch_pub32] Waiting for 0-conf callback on address1..."
  wait

  # 13. Send coins to address2, wait for callback
  trace 2 "\n\n[test_watch_pub32] ${BCyan}13. Send coins to address2...${Color_Off}\n"
  start_callback_server 1113
  # Let's use the bitcoin node directly to better simulate an external spend
  txid2=$(docker exec -it $(docker ps -q -f "name=cyphernode_bitcoin") bitcoin-cli -rpcwallet=spending01.dat sendtoaddress ${address2} 0.0001 | tr -d "\r\n")
#  txid2=$(exec_in_test_container curl -d '{"address":"'${address2}'","amount":0.001}' proxy:8888/spend | jq -r ".txid")
  trace 3 "[test_watch_pub32] txid2=${txid2}"
  trace 3 "[test_watch_pub32] Waiting for 0-conf callback on address2..."
  wait


  # 14. Call get_txns_by_watchlabel for label1, search sent tx
  trace 2 "\n\n[test_watch_pub32] ${BCyan}14. Call get_txns_by_watchlabel for label1...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/get_txns_by_watchlabel/${label1}/1000)
  trace 3 "[test_watch_pub32] response=${response}"
  txid=$(echo "${response}" | jq -r ".label_txns | map(select(.txid == \"${txid1}\"))[0] | .txid")
  trace 3 "[test_watch_pub32] txid searched=${txid}"
  if [ "${txid}" != "${txid1}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 14. Call get_txns_by_watchlabel for label1: \"${txid}\" != \"${txid1}\"!                                           ${Color_Off}\n"
    return 88
  fi

  # 15. Call get_txns_by_watchlabel for label2, search sent tx
  trace 2 "\n\n[test_watch_pub32] ${BCyan}15. Call get_txns_by_watchlabel for label2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/get_txns_by_watchlabel/${label2}/1000)
  trace 3 "[test_watch_pub32] response=${response}"
  txid=$(echo "${response}" | jq -r ".label_txns | map(select(.txid == \"${txid2}\"))[0] | .txid")
  trace 3 "[test_watch_pub32] txid searched=${txid}"
  if [ "${txid}" != "${txid2}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 15. Call get_txns_by_watchlabel for label2: \"${txid}\" != \"${txid2}\"!                                           ${Color_Off}\n"
    return 88
  fi


  # 16. Call get_unused_addresses_by_watchlabel with label1 /10, check address1 is NOT there
  trace 2 "\n\n[test_watch_pub32] ${BCyan}16. Call get_unused_addresses_by_watchlabel with label1 /10...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/get_unused_addresses_by_watchlabel/${label1}/10)
  trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".label_unused_addresses | map(select(.address == \"${address1}\"))[0] | .address")
  trace 3 "[test_watch_pub32] ${index1}th address searched=${address}"
  if [ "${address}" = "${address1}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 16. Call get_unused_addresses_by_watchlabel with label1 /10: \"${address}\" = \"${address1}\"!                                           ${Color_Off}\n"
    return 87
  fi

  # 17. Call get_unused_addresses_by_watchlabel with label2 /10, check address2 is NOT there
  trace 2 "\n\n[test_watch_pub32] ${BCyan}17. Call get_unused_addresses_by_watchlabel with label2 /10...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/get_unused_addresses_by_watchlabel/${label2}/10)
  trace 3 "[test_watch_pub32] response=${response}"
  address=$(echo "${response}" | jq -r ".label_unused_addresses | map(select(.address == \"${address2}\"))[0] | .address")
  trace 3 "[test_watch_pub32] ${index2}th address searched=${address}"
  if [ "${address}" = "${address2}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 17. Call get_unused_addresses_by_watchlabel with label2 /10: \"${address}\" = \"${address2}\"!                                           ${Color_Off}\n"
    return 87
  fi


  # 18. Call getactivexpubwatches
  trace 2 "\n\n[test_watch_pub32] ${BCyan}18. getactivexpubwatches...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivexpubwatches)
  trace 3 "[test_watch_pub32] response=${response}"
  last_imported_n1_x=$(echo "${response}" | jq -r ".watches | map(select(.pub32 == \"${xpub1}\"))[0] | .last_imported_n")
  trace 3 "[test_watch_pub32] last_imported_n1_x=${last_imported_n1_x}"
  last_imported_n2_x=$(echo "${response}" | jq -r ".watches | map(select(.pub32 == \"${xpub2}\"))[0] | .last_imported_n")
  trace 3 "[test_watch_pub32] last_imported_n2_x=${last_imported_n2_x}"
  if [ "${last_imported_n1_x}" -ne "$((100+${index1}))" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 18. Call getactivexpubwatches: \"${last_imported_n1_x}\" -ne \"$((100+${index1}))\"!                                           ${Color_Off}\n"
    return 90
  fi
  if [ "${last_imported_n2_x}" -ne "$((100+${index2}))" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 18. Call getactivexpubwatches \"${last_imported_n2_x}\" -ne \"$((100+${index2}))\"!                                           ${Color_Off}\n"
    return 95
  fi

  # 19. Call getactivewatchesbyxpub with xpub1, last n should be 10 more (index1 + 100)
  trace 2 "\n\n[test_watch_pub32] ${BCyan}19. Call getactivewatchesbyxpub with xpub1...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbyxpub/${xpub1})
  # trace 3 "[test_watch_pub32] response=${response}"
  index=$(echo "${response}" | jq -r "[.watches[].pub32_index] | index(${last_imported_n1_x})")
  trace 3 "[test_watch_pub32] index=${index}"
  if [ "${index}" != "${last_imported_n1_x}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 19. Call getactivewatchesbyxpub with xpub1: \"${index}\" != \"${last_imported_n1_x}\"!                                           ${Color_Off}\n"
    return 100
  fi

  # 20. Call getactivewatchesbyxpub with xpub2, last n should be 10 more (index2 + 100)
  trace 2 "\n\n[test_watch_pub32] ${BCyan}20. Call getactivewatchesbyxpub with xpub2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbyxpub/${xpub2})
  # trace 3 "[test_watch_pub32] response=${response}"
  index=$(echo "${response}" | jq -r "[.watches[].pub32_index] | index(${last_imported_n2_x})")
  trace 3 "[test_watch_pub32] index=${index}"
  if [ "${index}" != "${last_imported_n2_x}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 20. Call getactivewatchesbyxpub with xpub2: \"${index}\" != \"${last_imported_n2_x}\"!                                           ${Color_Off}\n"
    return 100
  fi


  # 21. Call unwatchxpubbyxpub with xpub1
  trace 2 "\n\n[test_watch_pub32] ${BCyan}21. unwatchxpubbyxpub with xpub1...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/unwatchxpubbyxpub/${xpub1})
  trace 3 "[test_watch_pub32] response=${response}"
  data=$(echo "${response}" | jq -re ".pub32")
  if [ "${xpub1}" != "${data}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 21. Call unwatchxpubbyxpub with xpub1!                                           ${Color_Off}\n"
    return 120
  fi

  # 22. Call unwatchxpubbylabel with label2
  trace 2 "\n\n[test_watch_pub32] ${BCyan}22. unwatchxpubbylabel with label2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/unwatchxpubbylabel/${label2})
  trace 3 "[test_watch_pub32] response=${response}"
  data=$(echo "${response}" | jq -re ".label")
  if [ "${label2}" != "${data}" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 22. Call unwatchxpubbylabel with label2 failed!                                           ${Color_Off}\n"
    return 130
  fi


  # 23. Call getactivewatchesbyxpub with xpub1, should be empty
  trace 2 "\n\n[test_watch_pub32] ${BCyan}23. getactivewatchesbyxpub with xpub1...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbyxpub/${xpub1})
  trace 3 "[test_watch_pub32] response=${response}"
  data=$(echo "${response}" | jq ".watches | length")
  if [ "${data}" -ne "0" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 23. getactivewatchesbyxpub xpub1 still watching!                                           ${Color_Off}\n"
    return 140
  fi

  # 24. Call getactivewatchesbyxpub with xpub2, should be empty
  trace 2 "\n\n[test_watch_pub32] ${BCyan}24. getactivewatchesbyxpub with xpub2...${Color_Off}\n"
  response=$(exec_in_test_container curl proxy:8888/getactivewatchesbyxpub/${xpub2})
  trace 3 "[test_watch_pub32] response=${response}"
  data=$(echo "${response}" | jq ".watches | length")
  if [ "${data}" -ne "0" ]; then
    trace 1 "\n\n[test_watch_pub32] ${On_Red}${BBlack} 24. getactivewatchesbyxpub xpub2 still watching!                                           ${Color_Off}\n"
    return 150
  fi

  trace 1 "\n\n[test_watch_pub32] ${On_IGreen}${BBlack} ALL GOOD!  Yayyyy!                                           ${Color_Off}\n"

}

start_callback_server() {
  trace 1 "\n\n[start_callback_server] ${BCyan}Let's start a callback server!...${Color_Off}\n"

  port=${1:-${callbackserverport}}
  docker run --rm -t --name tests-watch-pub32-cb --network=cyphernodenet alpine sh -c "nc -vlp${port} -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'" &

  # docker run --rm -it --name tests-watch-pub32-cb --network=cyphernodenet alpine sh -c "nc -vlkp1111 -e sh -c 'echo -en \"HTTP/1.1 200 OK\\\\r\\\\n\\\\r\\\\n\" ; echo -en \"\\033[40m\\033[0;37m\" >&2 ; date >&2 ; timeout 1 tee /dev/tty | cat ; echo -e \"\033[0m\" >&2'"
}

TRACING=3

stop_test_container
start_test_container

callbackserverport="1111"
callbackservername="tests-watch-pub32-cb"

trace 1 "\n\n[test_watch_pub32] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container apk add --update curl

test_watch_pub32

trace 1 "\n\n[test_watch_pub32] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[test_watch_pub32] ${BCyan}See ya!${Color_Off}\n"
