#!/bin/sh

apk add --update --no-cache openssl curl jq coreutils postgresql > /dev/null

. /gatekeeper/keys.properties

checkgatekeeper() {
  echo -e "\r\n\e[1;36mTesting Gatekeeper...\e[0;32m" > /dev/console

  local rc
  local id="001"
  local k
  eval k='$ukey_'$id

  local h64=$(echo -n '{"alg":"HS256","typ":"JWT"}' | basenc --base64url | tr -d '=')

  # Let's test expiration: 1 second in payload, request 2 seconds later

  local p64=$(echo -n '{"id":"'${id}'","exp":'$(date +"%s")'}' | basenc --base64url | tr -d '=')
  local s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r -binary | basenc --base64url | tr -d '=')
  local token="$h64.$p64.$s"

  echo "  Testing expired request... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /gatekeeper/certs/cert.pem https://gatekeeper:<%= gatekeeper_port %>/v0/getblockinfo)
  [ "${rc}" -ne "403" ] && return 10

  # Let's test authentication (signature)

  p64=$(echo -n '{"id":"'${id}'","exp":'$((`date +"%s"`+10))'}' | basenc --base64url | tr -d '=')
  s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r -binary | basenc --base64url | tr -d '=')
  token="$h64.$p64.a$s"

  echo "  Testing bad signature... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /gatekeeper/certs/cert.pem https://gatekeeper:<%= gatekeeper_port %>/v0/getblockinfo)
  [ "${rc}" -ne "401" ] && return 30

  # Let's test authorization (action access for groups)

  token="$h64.$p64.$s"

  echo "  Testing watcher trying to do a spender action... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /gatekeeper/certs/cert.pem https://gatekeeper:<%= gatekeeper_port %>/v0/getbalance)
  [ "${rc}" -ne "403" ] && return 40

  id="002"
  eval k='$ukey_'$id
  p64=$(echo -n '{"id":"'${id}'","exp":'$((`date +"%s"`+10))'}' | basenc --base64url | tr -d '=')
  s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r -binary | basenc --base64url | tr -d '=')
  token="$h64.$p64.$s"

  echo "  Testing spender trying to do an internal action call... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /gatekeeper/certs/cert.pem https://gatekeeper:<%= gatekeeper_port %>/v0/conf)
  [ "${rc}" -ne "403" ] && return 50


  id="003"
  eval k='$ukey_'$id
  p64=$(echo -n '{"id":"'${id}'","exp":'$((`date +"%s"`+10))'}' | basenc --base64url | tr -d '=')
  s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r -binary | basenc --base64url | tr -d '=')
  token="$h64.$p64.$s"

  echo "  Testing admin trying to do an internal action call... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /gatekeeper/certs/cert.pem https://gatekeeper:<%= gatekeeper_port %>/v0/conf)
  [ "${rc}" -ne "403" ] && return 60

  echo -e "\e[1;36mGatekeeper rocks!" > /dev/console

  return 0
}

checkpycoin() {
  echo -en "\r\n\e[1;36mTesting Pycoin... " > /dev/console
  local rc

  rc=$(curl -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" -s -o /dev/null -w "%{http_code}" http://pycoin:7777/derive)
  [ "${rc}" -ne "200" ] && return 100

  echo -e "\e[1;36mPycoin rocks!" > /dev/console

  return 0
}

checkpostgres() {
  echo -en "\r\n\e[1;36mTesting Postgres... " > /dev/console
  local rc

  pg_isready -h postgres -U cyphernode > /dev/null
  [ "${?}" -ne "0" ] && return 105

  echo -e "\e[1;36mPostgres rocks!" > /dev/console

  return 0
}

checkbroker() {
  echo -en "\r\n\e[1;36mTesting Broker... " > /dev/console
  local rc

  rc=$(mosquitto_pub -h broker -t "testtopic" -m "testbroker")
  [ "$?" -ne "0" ] && return 110

  echo -e "\e[1;36mBroker rocks!" > /dev/console

  return 0
}

checknotifier() {
  echo -en "\r\n\e[1;36mTesting Notifier... " > /dev/console
  local response
  local returncode

  nc -lp1111 -e sh -c 'echo -en "HTTP/1.1 200 OK\\r\\n\\r\\n" ; timeout 1 tee /dev/null ;' > /dev/null &
  response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"web\",\"url\":\"http://$(hostname):1111/notifiertest\",\"tor\":false}")
  returncode=$?
  [ "${returncode}" -ne "0" ] && return 115
  http_code=$(echo "${response}" | jq -r ".http_code")
  [ "${http_code}" -ge "400" ] && return 118

  echo -e "\e[1;36mNotifier rocks!" > /dev/console

  return 0
}

checknotifiertelegram() {
  echo -en "\r\n\e[1;36mTesting Notifier Telegram... " > /dev/console
  local response
  local returncode
  
  response=$(mosquitto_rr -h broker -W 15 -t notifier -e "response/$$" -m "{\"response-topic\":\"response/$$\",\"cmd\":\"sendToTelegramNoop\"}")
  returncode=$?
  [ "${returncode}" -ne "0" ] && return 115
  http_code=$(echo "${response}" | jq -r ".http_code")
  [ "${http_code}" -ge "400" ] && return 118
  [ "${http_code}" -eq "0" ] && return 119

  echo -e "\e[1;36mNotifier Telegram rocks!" > /dev/console

  return 0
}

checkots() {
  echo -en "\r\n\e[1;36mTesting OTSclient... " > /dev/console
  local rc

  # rc=$(curl -s -H "Content-Type: application/json" -d '{"hash":"123","callbackUrl":"http://callback"}' http://proxy:8888/ots_stamp)
  rc=$(curl -s otsclient:6666/stamp/123)
  echo "${rc}" | grep "Invalid hash 123 for sha256" > /dev/null
  [ "$?" -ne "0" ] && return 200

  echo -e "\e[1;36mOTSclient rocks!" > /dev/console

  return 0
}

checktor() {
  echo -en "\r\n\e[1;36mTesting Tor... " > /dev/console
  local rc

  curl -s --socks5-hostname tor:9050 https://check.torproject.org/ | cat | grep -qm 1 Congratulations
  [ "$?" -ne "0" ] && return 250

  echo -e "\e[1;36mTor rocks!" > /dev/console

  return 0
}

checkbitcoinnode() {
  echo -en "\r\n\e[1;36mTesting Bitcoin... " > /dev/console
  local rc

  rc=$(curl -s -o /dev/null -w "%{http_code}" http://proxy:8888/getbestblockhash)
  [ "${rc}" -ne "200" ] && return 300

  echo -e "\e[1;36mBitcoin node rocks!" > /dev/console

  return 0
}

checklnnode() {
  echo -en "\r\n\e[1;36mTesting Lightning... " > /dev/console
  local rc

  rc=$(curl -s -o /dev/null -w "%{http_code}" http://proxy:8888/ln_getinfo)
  [ "${rc}" -ne "200" ] && return 400

  echo -e "\e[1;36mLN node rocks!" > /dev/console

  return 0
}

checkservice() {
  local interval=15
  local totaltime=180
  local outcome
  local returncode=0
  local endtime=$(($(date +%s) + ${totaltime}))
  local result

  echo -e "\r\n\e[1;36mTesting if Cyphernode is up and running... \e[0;36mI will keep trying during up to $((${totaltime} / 60)) minutes to give time to Docker to deploy everything...\e[0;32m" > /dev/console

  while :
  do
    outcome=0
    for container in gatekeeper proxy proxycron broker notifier pycoin postgres <%= (features.indexOf('otsclient') != -1)?'otsclient ':'' %><%= (features.indexOf('tor') != -1)?'tor ':'' %>bitcoin  <%= (features.indexOf('lightning') != -1)?'lightning ':'' %>; do
      echo -e "  \e[0;32mVerifying \e[0;33m${container}\e[0;32m..." > /dev/console
      (ping -c 10 ${container} 2> /dev/null | grep "0% packet loss" > /dev/null) &
      eval ${container}=$!
    done
    for container in gatekeeper proxy proxycron broker notifier pycoin postgres <%= (features.indexOf('otsclient') != -1)?'otsclient ':'' %><%= (features.indexOf('tor') != -1)?'tor ':'' %>bitcoin  <%= (features.indexOf('lightning') != -1)?'lightning ':'' %>; do
      eval wait '$'${container} ; returncode=$? ; outcome=$((${outcome} + ${returncode}))
      eval c_${container}=${returncode}
    done

    # If '0% packet loss' everywhere or 5 minutes passed, we get out of this loop
    ([ "${outcome}" -eq "0" ] || [ $(date +%s) -gt ${endtime} ]) && break

    echo -e "\e[1;31mCyphernode still not ready, will retry every ${interval} seconds for $((${totaltime} / 60)) minutes ($((${endtime} - $(date +%s))) seconds left)." > /dev/console

    sleep ${interval}
  done

  #  "containers": [
  #    { "name": "gatekeeper", "active":true },
  #    { "name": "proxy", "active":true },
  #    { "name": "proxycron", "active":true },
  #    { "name": "pycoin", "active":true },
  #    { "name": "postgres", "active":true },
  #    { "name": "otsclient", "active":true },
  #    { "name": "tor", "active":true },
  #    { "name": "bitcoin", "active":true },
  #    { "name": "lightning", "active":true },
  #  ]
  for container in gatekeeper proxy proxycron broker notifier pycoin postgres <%= (features.indexOf('otsclient') != -1)?'otsclient ':'' %><%= (features.indexOf('tor') != -1)?'tor ':'' %>bitcoin  <%= (features.indexOf('lightning') != -1)?'lightning ':'' %>; do
    [ -n "${result}" ] && result="${result},"
    result="${result}{\"name\":\"${container}\",\"active\":"
    eval "returncode=\$c_${container}"
    if [ "${returncode}" -eq "0" ]; then
      result="${result}true}"
    else
      result="${result}false}"
    fi
  done

  result="\"containers\":[${result}]"

  echo $result

  return ${outcome}
}

timeout_feature() {
  local interval=15
  local totaltime=${2:-120}
  local testwhat=${1}
  local returncode
  local endtime=$(($(date +%s) + ${totaltime}))

  while :
  do
    eval ${testwhat}
    returncode=$?

    # If no error or 2 minutes passed, we get out of this loop
    ([ "${returncode}" -eq "0" ] || [ $(date +%s) -gt ${endtime} ]) && break

    echo -e "\e[1;31mMaybe it's too early, I'll retry every ${interval} seconds for $((${totaltime} / 60)) minutes ($((${endtime} - $(date +%s))) seconds left)." > /dev/console

    sleep ${interval}
  done

  return ${returncode}
}

feature_status() {
  local returncode=${1}
  local errormsg=${2}

  [ "${returncode}" -eq "0" ] && echo "true"
  [ "${returncode}" -ne "0" ] && echo "false" && echo -e "\e[1;31m${errormsg}" > /dev/console
}

# /proxy/installation.json will contain something like that:
#{
#  "containers": [
#    { "name": "gatekeeper", "active":true },
#    { "name": "proxy", "active":true },
#    { "name": "proxycron", "active":true },
#    { "name": "pycoin", "active":true },
#    { "name": "postgres", "active":true },
#    { "name": "otsclient", "active":true },
#    { "name": "tor", "active":true },
#    { "name": "bitcoin", "active":true },
#    { "name": "lightning", "active":true },
#  ],
#  "features": [
#    { "name": "gatekeeper", "working":true },
#    { "name": "pycoin", "working":true },
#    { "name": "postgres", "working":true },
#    { "name": "otsclient", "working":true },
#    { "name": "tor", "working":true },
#    { "name": "bitcoin", "working":true },
#    { "name": "lightning", "working":true },
#  ]
#}

# Let's first see if everything is up.

echo "EXIT_STATUS=1" > /dist/exitStatus.sh

#############################
# Ping containers and PROXY #
#############################

workingproxy="true"
containers=$(checkservice)
returncode=$?
finalreturncode=${returncode}
if [ "${returncode}" -ne "0" ]; then
  echo -e "\e[1;31mCyphernode could not fully start properly within delay." > /dev/console
  status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"proxy\") | .active")
  if [ "${status}" = "false" ]; then
    echo -e "\r\n\e[1;31mThe Proxy, the main Cyphernode's component, is not responding.  You'll see errors for the other components.  Please check the logs." > /dev/console
    workingproxy="false"
  fi
else
  echo -e "\e[1;36mCyphernode seems to be correctly deployed.  Let's run more thorough tests..." > /dev/console
fi

# Let's now check each feature fonctionality...
#  "features": [
#    { "name": "gatekeeper", "working":true },
#    { "name": "pycoin", "working":true },
#    { "name": "postgres", "working":true },
#    { "name": "otsclient", "working":true },
#    { "name": "tor", "working":true },
#    { "name": "bitcoin", "working":true },
#    { "name": "lightning", "working":true },
#  ]

#############################
# PROXY                     #
#############################

if [ ! -f /container_monitor/proxy_dbfailed ]; then
  echo -e "\r\n\e[1;36mWaiting for Proxy to be ready... " > /dev/console
  timeout_feature '[ -f "/container_monitor/proxy_ready" ]' 300
  returncode=$?
  if [ "${returncode}" -ne "0" ]; then
    echo -e "\r\n\e[1;31mThe proxy is still not ready.  It may be migrating large quantity of data?  Please check the logs for more details." > /dev/console
    workingproxy="false"
  fi
fi
if [ -f /container_monitor/proxy_dbfailed ]; then
  echo -e "\r\n\e[1;31mThe proxy's database migration failed.  Please check proxy.log for more details." > /dev/console
  workingproxy="false"
fi

if [ "${workingproxy}" = "false" ]; then
  echo -e "\r\n\e[1;31mThe Proxy, the main Cyphernode's component, is not ready.  Cyphernode can't be run without the proxy component." > /dev/console
  echo -e "\r\n\e[1;31mThe other components will fail next, this is normal." > /dev/console
fi

result="${containers},\"features\":[{\"coreFeature\":true,\"name\":\"proxy\",\"working\":${workingproxy}}"

#############################
# POSTGRES                  #
#############################

result="${result},{\"coreFeature\":true,\"name\":\"postgres\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"postgres\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  timeout_feature checkpostgres
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Postgres error!')}"

#############################
# GATEKEEPER                #
#############################

result="${result},{\"coreFeature\":true,\"name\":\"gatekeeper\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"gatekeeper\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  timeout_feature checkgatekeeper
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Gatekeeper error!')}"

#############################
# BROKER                    #
#############################

result="${result},{\"coreFeature\":true,\"name\":\"broker\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"broker\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  timeout_feature checkbroker
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Broker error!')}"

#############################
# NOTIFIER                  #
#############################

result="${result},{\"coreFeature\":true,\"name\":\"notifier\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"notifier\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  timeout_feature checknotifier
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Notifier error!')}"

<% if (features.indexOf('telegram') != -1) { %>
#############################
# NOTIFIER TELEGRAM         #
#############################

result="${result},{\"coreFeature\":true, \"name\":\"notifier telegram\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"notifier\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  timeout_feature checknotifiertelegram
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Notifier Telegram error!')}"
<% } %>

#############################
# PYCOIN                    #
#############################

result="${result},{\"coreFeature\":true,\"name\":\"pycoin\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"pycoin\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  timeout_feature checkpycoin
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Pycoin error!')}"

<% if (features.indexOf('otsclient') != -1) { %>
#############################
# OTSCLIENT                 #
#############################

result="${result},{\"coreFeature\":false,\"name\":\"otsclient\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"otsclient\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  timeout_feature checkots
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'OTSclient error!')}"
<% } %>

<% if (features.indexOf('tor') != -1) { %>
#############################
# TOR                       #
#############################

result="${result},{\"coreFeature\":false,\"name\":\"tor\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"tor\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  echo -e "\r\n\e[1;36mWaiting for Tor to be ready... " > /dev/console
  timeout_feature '[ -f "/container_monitor/tor_ready" ]'
  timeout_feature checktor
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Tor error!')}"
<% } %>

#############################
# BITCOIN                   #
#############################

result="${result},{\"coreFeature\":true,\"name\":\"bitcoin\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"bitcoin\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  echo -e "\r\n\e[1;36mWaiting for Bitcoin Core to be ready... " > /dev/console
  timeout_feature '[ -f "/container_monitor/bitcoin_ready" ]'
  timeout_feature checkbitcoinnode
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Bitcoin error!')}"

<% if (features.indexOf('lightning') != -1) { %>
#############################
# LIGHTNING                 #
#############################

result="${result},{\"coreFeature\":false,\"name\":\"lightning\",\"working\":"
status=$(echo "{${containers}}" | jq ".containers[] | select(.name == \"lightning\") | .active")
if [[ "${workingproxy}" = "true" && "${status}" = "true" ]]; then
  echo -e "\r\n\e[1;36mWaiting for C-Lightning to be ready... " > /dev/console
  timeout_feature '[ -f "/container_monitor/lightning_ready" ]'
  timeout_feature checklnnode
  returncode=$?
else
  returncode=1
fi
finalreturncode=$((${returncode} | ${finalreturncode}))
result="${result}$(feature_status ${returncode} 'Lightning error!')}"

<% } %>

#############################

result="{${result}]}"

echo "${result}" > /gatekeeper/installation.json

echo "EXIT_STATUS=${finalreturncode}" > /dist/exitStatus.sh

<% if (features.indexOf('tor') !== -1 && torifyables && torifyables.indexOf('tor_traefik') !== -1) { %>
echo "TOR_TRAEFIK_HOSTNAME=$(cat /dist/.cyphernodeconf/tor/traefik/hidden_service/hostname)" >> /dist/exitStatus.sh
<% } %>
