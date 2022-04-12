#!/bin/bash

. ./colors.sh

# We just want to test the authentication/authorization, not the actual called function
# You need jq installed for these tests to run correctly

# This will test this structure of access (api.properties):

# # Watcher can do stuff
# # Spender can do what the watcher can do plus more stuff
# # Admin can do what the spender can do plus even more stuff

# # Stats can:
# action_helloworld=stats
# action_getblockchaininfo=stats
# action_installation_info=stats
# action_getmempoolinfo=stats
# action_getblockhash=stats
#
# # Watcher can do what the stats can do, plus:
# action_watch=watcher
# action_unwatch=watcher
# action_watchxpub=watcher
# action_unwatchxpubbyxpub=watcher
# action_unwatchxpubbylabel=watcher
# action_getactivewatchesbyxpub=watcher
# action_getactivewatchesbylabel=watcher
# action_getactivexpubwatches=watcher
# action_get_txns_by_watchlabel=watcher
# action_get_unused_addresses_by_watchlabel=watcher
# action_watchtxid=watcher
# action_unwatchtxid=watcher
# action_getactivewatches=watcher
# action_getbestblockhash=watcher
# action_getbestblockinfo=watcher
# action_getblockinfo=watcher
# action_gettransaction=watcher
# action_ots_verify=watcher
# action_ots_info=watcher
# action_ln_getinfo=watcher
# action_ln_create_invoice=watcher
# action_ln_getconnectionstring=watcher
# action_ln_decodebolt11=watcher
# action_ln_listpeers=watcher
# action_ln_getroute=watcher
# action_ln_listpays=watcher
# action_ln_paystatus=watcher
# action_bitcoin_estimatesmartfee=watcher
#
# # Spender can do what the watcher can do, plus:
# action_get_txns_spending=spender
# action_getbalance=spender
# action_getbalances=spender
# action_getbalancebyxpub=spender
# action_getbalancebyxpublabel=spender
# action_getnewaddress=spender
# action_spend=spender
# action_bumpfee=spender
# action_addtobatch=spender
# action_batchspend=spender
# action_deriveindex=spender
# action_derivepubpath=spender
# action_deriveindex_bitcoind=spender
# action_derivepubpath_bitcoind=spender
# action_ln_pay=spender
# action_ln_newaddr=spender
# action_ots_stamp=spender
# action_ots_getfile=spender
# action_ln_getinvoice=spender
# action_ln_delinvoice=spender
# action_ln_connectfund=spender
# action_ln_listfunds=spender
# action_ln_withdraw=spender
# action_createbatcher=spender
# action_updatebatcher=spender
# action_removefrombatch=spender
# action_listbatchers=spender
# action_getbatcher=spender
# action_getbatchdetails=spender
#
# # Admin can do what the spender can do, plus:
#
#
# # Should be called from inside the Docker network only:
# action_conf=internal
# action_newblock=internal
# action_executecallbacks=internal
# action_ots_backoffice=internal
#
#

trace() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -en "$(date -u +%FT%TZ) ${2}" 1>&2
  fi
}

trace_following() {
  if [ "${1}" -le "${TRACING}" ]; then
    echo -en "${2}" 1>&2
  fi
}

start_test_container() {
  trace 1 "[stop_test_container] ${BCyan}Starting test container...${Color_Off}\n"

  docker run -d --rm -t --name tests-gatekeeper --network=cyphernodenet alpine

  sleep 2
}

stop_test_container() {
  trace 1 "[stop_test_container] ${BCyan}Stopping existing containers if they are running...${Color_Off}\n"

  local containers=$(docker ps -q -f "name=tests-gatekeeper")
  if [ -n "${containers}" ]; then
    docker stop ${containers}
  fi
}

exec_in_test_container() {
  local response
  local returncode
  response=$(docker exec -it tests-gatekeeper "$@")
  returncode=${?}
  echo -n "${response}" | tr -d '\r\n'
  return ${returncode}
}

exec_in_test_container_leave_lf() {
  local response
  local returncode
  response=$(docker exec -it tests-gatekeeper "$@")
  returncode=${?}
  echo -n "${response}"
  return ${returncode}
}

test_auth() {
  local fn=${1}
  local token=${2}
  local has_access=${3}
  local httperrorcode=${4}
  local returncode
  local httpcode

  trace 2 "[test_auth] ${BCyan}action=${fn}...${Color_Off}"
  httpcode=$(exec_in_test_container curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper:2009/v0/${fn})
  returncode=${?}

  if ${has_access}; then
    trace_following 2 " has access... "
  else
    trace_following 2 " has NOT access... "
  fi

  if [ "${returncode}" -ne "0" ] || ${has_access} && [ "${httpcode}" -eq "${httperrorcode}" ] || ! ${has_access} && [ "${httpcode}" -ne "${httperrorcode}" ]; then
    trace_following 1 "${On_Red}${BBlack} curl code=${returncode}, HTTP code=${httpcode}!${Color_Off}\n"
    return 10
  else
    trace_following 2 "${On_IGreen}${BBlack}     OK     ${Color_Off}\n"
  fi
}

test_authorization() {
  test_auth ${1} ${2} ${3} 403
  return $?
}

test_authentication() {
  test_auth ${1} ${2} ${3} 401
  return $?
}

generate_token() {
  local id=${1}
  local expired=${2:-false}
  local key
  local groups

  key=$(exec_in_test_container sh -c 'source /keys.properties ; echo $ukey_'${id})
  groups=$(exec_in_test_container sh -c 'source /keys.properties ; echo $ugroups_'${id})
  trace 3 "[generate_token] id=${id}\n"
  trace 3 "[generate_token] key=${key}\n"
  trace 3 "[generate_token] groups=${groups}\n"

  local h64broken=$(exec_in_test_container sh -c "echo -n '{\"alg\":\"HS256\",\"typ\":\"JWT\"}' | base64")
  trace 3 "[generate_token] h64broken=${h64broken}\n"
  local h64=$(exec_in_test_container sh -c "echo -n '{\"alg\":\"HS256\",\"typ\":\"JWT\"}' | basenc --base64url | tr -d '='")
  trace 3 "[generate_token]       h64=${h64}\n"
  local d=$(exec_in_test_container date +"%s")
  if ! ${expired}; then
    d=$((d+100000))
  fi
  trace 3 "[generate_token] d=${d}\n"
  local p64=$(exec_in_test_container sh -c "echo -n '{\"id\":\"${id}\",\"exp\":${d}}' | basenc --base64url | tr -d '='")
  trace 3 "[generate_token] p64=${p64}\n"
  local sig=$(exec_in_test_container sh -c "echo -n \"${h64}.${p64}\" | openssl dgst -hmac \"${key}\" -sha256 -r -binary | basenc --base64url | tr -d '='")
  trace 3 "[generate_token] sig=${sig}\n"
  local token="${h64}.${p64}.${sig}"
  trace 3 "[generate_token] token=${token}\n\n"

  trace 1 "[test_gatekeeper] ${BCyan}Current user ${id} with groups ${groups}${Color_Off}\n"

  echo -n "${token}"
}

generate_broken_token() {
  local id=${1}
  local key
  local groups

  key=$(exec_in_test_container sh -c 'source /keys.properties ; echo $ukey_'${id})
  groups=$(exec_in_test_container sh -c 'source /keys.properties ; echo $ugroups_'${id})
  trace 3 "[generate_token] id=${id}\n"
  trace 3 "[generate_token] key=${key}\n"
  trace 3 "[generate_token] groups=${groups}\n"

  local h64broken=$(exec_in_test_container sh -c "echo -n '{\"alg\":\"HS256\",\"typ\":\"JWT\"}' | base64")
  trace 3 "[generate_token] h64broken=${h64broken}\n"
  local d=$(exec_in_test_container date +"%s")
  trace 3 "[generate_token] d=${d}\n"
  local p64broken=$(exec_in_test_container sh -c "echo -n '{\"id\":\"${id}\",\"exp\":$((d+100000))}' | base64")
  trace 3 "[generate_token] p64broken=${p64broken}\n"
  local sigbroken=$(exec_in_test_container sh -c "echo -n \"${h64}.${p64}\" | openssl dgst -hmac \"${key}\" -sha256 -r | cut -sd ' ' -f1")
  trace 3 "[generate_token] sigbroken=${sigbroken}\n"
  local token="${h64broken}.${p64broken}.${sigbroken}"
  trace 3 "[generate_token] token=${token}\n\n"

  trace 1 "[test_gatekeeper] ${BCyan}Current user ${id} with groups ${groups}${Color_Off}\n"

  echo -n "${token}"
}

test_functions_with_broken_token() {
  trace 1 "\n\n[test_functions_with_broken_token] ${BCyan}Let's test functions with broken token...${Color_Off}\n\n"

  local id=${1}
  local token=$(generate_broken_token ${id})
  local has_access=${2}

  # Stats can:
  # action_helloworld=stats
  test_authorization "helloworld" "${token}" ${has_access} || return 10

  # action_getblockchaininfo=stats
  test_authorization "getblockchaininfo" "${token}" ${has_access} || return 20

  # action_installation_info=stats
  test_authorization "installation_info" "${token}" ${has_access} || return 30

  # action_getmempoolinfo=stats
  test_authorization "getmempoolinfo" "${token}" ${has_access} || return 40

  # action_getblockhash=stats
  test_authorization "getblockhash" "${token}" ${has_access} || return 50

  trace 1 "\n\n[test_functions_with_broken_token] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

test_functions_with_wrong_token() {
  trace 1 "\n\n[test_functions_with_wrong_token] ${BCyan}Let's test functions with wrong token (we will receive HTTP 401 Unauthorized here)...${Color_Off}\n\n"

  local id=${1}
  local token=aaa$(generate_token ${id})aaa
  local has_access=false

  # Stats can:
  # action_helloworld=stats
  test_authentication "helloworld" "${token}" ${has_access} || return 10

  # action_getblockchaininfo=stats
  test_authentication "getblockchaininfo" "${token}" ${has_access} || return 20

  # action_installation_info=stats
  test_authentication "installation_info" "${token}" ${has_access} || return 30

  # action_getmempoolinfo=stats
  test_authentication "getmempoolinfo" "${token}" ${has_access} || return 40

  # action_getblockhash=stats
  test_authentication "getblockhash" "${token}" ${has_access} || return 50

  trace 1 "\n\n[test_functions_with_wrong_token] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

test_stats_functions() {
  trace 1 "\n\n[test_gatekeeper] ${BCyan}Let's test stats functions...${Color_Off}\n\n"

  local id=${1}
  local token=$(generate_token ${id})
  local has_access=${2}

  # Stats can:
  # action_helloworld=stats
  test_authorization "helloworld" "${token}" ${has_access} || return 10

  # action_getblockchaininfo=stats
  test_authorization "getblockchaininfo" "${token}" ${has_access} || return 20

  # action_installation_info=stats
  test_authorization "installation_info" "${token}" ${has_access} || return 30

  # action_getmempoolinfo=stats
  test_authorization "getmempoolinfo" "${token}" ${has_access} || return 40

  # action_getblockhash=stats
  test_authorization "getblockhash" "${token}" ${has_access} || return 50

  trace 1 "\n\n[test_stats_functions] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

test_watcher_functions() {
  trace 1 "\n\n[test_watcher_functions] ${BCyan}Let's test watcher functions...${Color_Off}\n\n"

  local id=${1}
  local token=$(generate_token ${id})
  local has_access=${2}

  # Watcher can:
  # action_watch=watcher
  test_authorization "watch" "${token}" ${has_access} || return 10

  # action_unwatch=watcher
  test_authorization "unwatch" "${token}" ${has_access} || return 20

  # action_watchxpub=watcher
  test_authorization "watchxpub" "${token}" ${has_access} || return 30

  # action_unwatchxpubbyxpub=watcher
  test_authorization "unwatchxpubbyxpub" "${token}" ${has_access} || return 40

  # action_unwatchxpubbylabel=watcher
  test_authorization "unwatchxpubbylabel" "${token}" ${has_access} || return 50

  # action_getactivewatchesbyxpub=watcher
  test_authorization "getactivewatchesbyxpub" "${token}" ${has_access} || return 60

  # action_getactivewatchesbylabel=watcher
  test_authorization "getactivewatchesbylabel" "${token}" ${has_access} || return 70

  # action_getactivexpubwatches=watcher
  test_authorization "getactivexpubwatches" "${token}" ${has_access} || return 80

  # action_get_txns_by_watchlabel=watcher
  test_authorization "get_txns_by_watchlabel" "${token}" ${has_access} || return 90

  # action_get_unused_addresses_by_watchlabel=watcher
  test_authorization "get_unused_addresses_by_watchlabel" "${token}" ${has_access} || return 100

  # action_watchtxid=watcher
  test_authorization "watchtxid" "${token}" ${has_access} || return 110

  # action_unwatchtxid=watcher
  test_authorization "unwatchtxid" "${token}" ${has_access} || return 120

  # action_getactivewatches=watcher
  test_authorization "getactivewatches" "${token}" ${has_access} || return 130

  # action_getbestblockhash=watcher
  test_authorization "getbestblockhash" "${token}" ${has_access} || return 140

  # action_getbestblockinfo=watcher
  test_authorization "getbestblockinfo" "${token}" ${has_access} || return 150

  # action_getblockinfo=watcher
  test_authorization "getblockinfo" "${token}" ${has_access} || return 160

  # action_gettransaction=watcher
  test_authorization "gettransaction" "${token}" ${has_access} || return 170

  # action_ots_verify=watcher
  test_authorization "ots_verify" "${token}" ${has_access} || return 180

  # action_ots_info=watcher
  test_authorization "ots_info" "${token}" ${has_access} || return 190

  # action_ln_getinfo=watcher
  test_authorization "ln_getinfo" "${token}" ${has_access} || return 200

  # action_ln_create_invoice=watcher
  test_authorization "ln_create_invoice" "${token}" ${has_access} || return 210

  # action_ln_getconnectionstring=watcher
  test_authorization "ln_getconnectionstring" "${token}" ${has_access} || return 220

  # action_ln_decodebolt11=watcher
  test_authorization "ln_decodebolt11" "${token}" ${has_access} || return 230

  # action_ln_listpeers=watcher
  test_authorization "ln_listpeers" "${token}" ${has_access} || return 240

  # action_ln_getroute=watcher
  test_authorization "ln_getroute" "${token}" ${has_access} || return 250

  # action_ln_listpays=watcher
  test_authorization "ln_listpays" "${token}" ${has_access} || return 260

  # action_ln_paystatus=watcher
  test_authorization "ln_paystatus" "${token}" ${has_access} || return 270

  # action_bitcoin_estimatesmartfee=watcher
  test_authorization "bitcoin_estimatesmartfee" "${token}" ${has_access} || return 280

  trace 1 "\n\n[test_watcher_functions] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

test_spender_functions() {
  trace 1 "\n\n[test_spender_functions] ${BCyan}Let's test spender functions...${Color_Off}\n"

  local id=${1}
  local token=$(generate_token ${id})
  local has_access=${2}

  # Spender can do what the watcher can do, plus:
  # action_get_txns_spending=spender
  test_authorization "get_txns_spending" "${token}" ${has_access} || return 10

  # action_getbalance=spender
  test_authorization "getbalance" "${token}" ${has_access} || return 10

  # action_getbalances=spender
  test_authorization "getbalances" "${token}" ${has_access} || return 10

  # action_getbalancebyxpub=spender
  test_authorization "getbalancebyxpub" "${token}" ${has_access} || return 10

  # action_getbalancebyxpublabel=spender
  test_authorization "getbalancebyxpublabel" "${token}" ${has_access} || return 10

  # action_getnewaddress=spender
  test_authorization "getnewaddress" "${token}" ${has_access} || return 10

  # action_spend=spender
  test_authorization "spend" "${token}" ${has_access} || return 10

  # action_bumpfee=spender
  test_authorization "bumpfee" "${token}" ${has_access} || return 10

  # action_addtobatch=spender
  test_authorization "addtobatch" "${token}" ${has_access} || return 10

  # action_batchspend=spender
  test_authorization "batchspend" "${token}" ${has_access} || return 10

  # action_deriveindex=spender
  test_authorization "deriveindex" "${token}" ${has_access} || return 10

  # action_derivepubpath=spender
  test_authorization "derivepubpath" "${token}" ${has_access} || return 10

  # action_deriveindex_bitcoind=spender
  test_authorization "deriveindex_bitcoind" "${token}" ${has_access} || return 10

  # action_derivepubpath_bitcoind=spender
  test_authorization "derivepubpath_bitcoind" "${token}" ${has_access} || return 10

  # action_ln_pay=spender
  test_authorization "ln_pay" "${token}" ${has_access} || return 10

  # action_ln_newaddr=spender
  test_authorization "ln_newaddr" "${token}" ${has_access} || return 10

  # action_ots_stamp=spender
  test_authorization "ots_stamp" "${token}" ${has_access} || return 10

  # action_ots_getfile=spender
  test_authorization "ots_getfile" "${token}" ${has_access} || return 10

  # action_ln_getinvoice=spender
  test_authorization "ln_getinvoice" "${token}" ${has_access} || return 10

  # action_ln_delinvoice=spender
  test_authorization "ln_delinvoice" "${token}" ${has_access} || return 10

  # action_ln_connectfund=spender
  test_authorization "ln_connectfund" "${token}" ${has_access} || return 10

  # action_ln_listfunds=spender
  test_authorization "ln_listfunds" "${token}" ${has_access} || return 10

  # action_ln_withdraw=spender
  test_authorization "ln_withdraw" "${token}" ${has_access} || return 10

  # action_createbatcher=spender
  test_authorization "createbatcher" "${token}" ${has_access} || return 10

  # action_updatebatcher=spender
  test_authorization "updatebatcher" "${token}" ${has_access} || return 10

  # action_removefrombatch=spender
  test_authorization "removefrombatch" "${token}" ${has_access} || return 10

  # action_listbatchers=spender
  test_authorization "listbatchers" "${token}" ${has_access} || return 10

  # action_getbatcher=spender
  test_authorization "getbatcher" "${token}" ${has_access} || return 10

  # action_getbatchdetails=spender
  test_authorization "getbatchdetails" "${token}" ${has_access} || return 10

  trace 1 "\n\n[test_spender_functions] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

test_admin_functions() {
  trace 1 "\n\n[test_admin_functions] ${BCyan}Let's test admin functions...${Color_Off}\n"

  # Admin can do what the spender can do, plus:
  trace 1 "\n\n[test_admin_functions] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

test_internal_functions() {
  trace 1 "\n\n[test_internal_functions] ${BCyan}Let's test internal functions...${Color_Off}\n"

  local id=${1}
  local token=$(generate_token ${id})
  local has_access=${2}

  # Should be called from inside the Docker network only:
  # action_conf=internal
  test_authorization "conf" "${token}" ${has_access} || return 10

  # action_newblock=internal
  test_authorization "newblock" "${token}" ${has_access} || return 10

  # action_executecallbacks=internal
  test_authorization "executecallbacks" "${token}" ${has_access} || return 10

  # action_ots_backoffice=internal
  test_authorization "ots_backoffice" "${token}" ${has_access} || return 10

  trace 1 "\n\n[test_internal_functions] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

test_expired() {
  trace 1 "\n\n[test_expired] ${BCyan}Let's test calling a function with an expired token (we will receive HTTP 403 Forbidden here)...${Color_Off}\n\n"

  local id=${1}
  local token=$(generate_token ${id} true)
  local has_access=false

  # Stats can:
  # action_helloworld=stats
  test_authorization "helloworld" "${token}" ${has_access} || return 10

  trace 1 "\n\n[test_expired] ${On_IGreen}${BBlack} SUCCESS with user ${id}! ${Color_Off}\n"
}

TRACING=3

stop_test_container
start_test_container

trace 1 "\n\n[test_gatekeeper] ${BCyan}Installing needed packages...${Color_Off}\n"
exec_in_test_container_leave_lf apk add --update curl coreutils openssl

# Copy keys to test container
trace 1 "\n\n[test_gatekeeper] ${BCyan}Copying keys and certs to test container...${Color_Off}\n"
gatekeeperid=$(docker ps -q -f "name=cyphernode.gatekeeper")
testid=$(docker ps -q -f "name=tests-gatekeeper")
docker cp ${gatekeeperid}:/etc/nginx/conf.d/keys.properties - | docker cp - ${testid}:/
docker cp ${gatekeeperid}:/etc/ssl/certs/cert.pem - | docker cp - ${testid}:/

# Test with an expired token
# Test functions with broken legacy token
# Test functions with wrong token
# Stats functions with a stats
# Stats functions with a watcher
# Stats functions with a spender
# Stats functions with a admin
# Watcher functions with a stats
# Watcher functions with a watcher
# Watcher functions with a spender
# Watcher functions with a admin
# Spending functions with a stats
# Spending functions with a watcher
# Spending functions with a spender
# Spending functions with a admin
# Internal functions with a stats
# Internal functions with a watcher
# Internal functions with a spender
# Internal functions with a admin
test_expired 003 \
&& test_functions_with_broken_token 003 true \
&& test_functions_with_wrong_token 003 true \
&& test_stats_functions 000 true \
&& test_stats_functions 001 true \
&& test_stats_functions 002 true \
&& test_stats_functions 003 true \
&& test_watcher_functions 000 false \
&& test_watcher_functions 001 true \
&& test_watcher_functions 002 true \
&& test_watcher_functions 003 true \
&& test_spender_functions 000 false \
&& test_spender_functions 001 false \
&& test_spender_functions 002 true \
&& test_spender_functions 003 true \
&& test_internal_functions 000 false \
&& test_internal_functions 001 false \
&& test_internal_functions 002 false \
&& test_internal_functions 003 false \
|| trace 1 "\n\n[test_gatekeeper] ${On_Red}${BBlack} test_watcher_functions error: ${?} ${Color_Off}\n"

trace 1 "\n\n[test_gatekeeper] ${BCyan}Tearing down...${Color_Off}\n"
wait

stop_test_container

trace 1 "\n\n[test_gatekeeper] ${BCyan}See ya!${Color_Off}\n"
