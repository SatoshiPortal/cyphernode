#!/bin/sh

apk add --update --no-cache openssl curl

. keys.properties

checkgatekeeper() {
  echo ; echo "Testing Gatekeeper..." > /dev/console

  local rc
  local id="001"
  local k
  eval k='$ukey_'$id

  local h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)

  # Let's test expiration: 1 second in payload, request 2 seconds later

  local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+1))}" | base64)
  local s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  local token="$h64.$p64.$s"

  echo "  Sleeping 2 seconds... " > /dev/console
  sleep 2

  echo "  Testing expired request... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/getblockinfo)
  [ "${rc}" -ne "403" ] && return 10

  # Let's test authentication (signature)

  p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
  s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  token="$h64.$p64.a$s"

  echo "  Testing bad signature... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/getblockinfo)
  [ "${rc}" -ne "403" ] && return 30

  # Let's test authorization (action access for groups)

  token="$h64.$p64.$s"

  echo "  Testing watcher trying to do a spender action... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/getbalance)
  [ "${rc}" -ne "403" ] && return 40

  id="002"
  eval k='$ukey_'$id
  p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
  s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  token="$h64.$p64.$s"

  echo "  Testing spender trying to do an internal action call... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/conf)
  [ "${rc}" -ne "403" ] && return 50


  id="003"
  eval k='$ukey_'$id
  p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
  s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  token="$h64.$p64.$s"

  echo "  Testing admin trying to do an internal action call... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/conf)
  [ "${rc}" -ne "403" ] && return 60

  echo "***** Gatekeeper rocks!" > /dev/console

  return 0
}

checkpycoin() {
  echo ; echo "Testing Pycoin..." > /dev/console
  local rc
  local id="002"
  local k
  eval k='$ukey_'$id

  local h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)

  local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
  local s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  local token="$h64.$p64.$s"

  echo "  Testing pycoin... " > /dev/console
  rc=$(curl -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/derivepubpath)
  [ "${rc}" -ne "200" ] && return 100

  echo "***** Pycoin rocks!" > /dev/console

  return 0
}

checkots() {
  echo ; echo "Testing OTSclient..." > /dev/console
  local rc
  local id="002"
  local k
  eval k='$ukey_'$id

  local h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)

  local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
  local s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  local token="$h64.$p64.$s"

  echo "  Testing otsclient... " > /dev/console
  rc=$(curl -s -H "Content-Type: application/json" -d '{"hash":"123","callbackUrl":"http://callback"}' -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/ots_stamp)
  echo "${rc}" | grep "Invalid hash 123 for sha256" > /dev/null
  [ "$?" -ne "0" ] && return 200

  echo "***** OTSclient rocks!" > /dev/console

  return 0
}

checkbitcoinnode() {
  echo ; echo "Testing Bitcoin..." > /dev/console
  local rc
  local id="002"
  local k
  eval k='$ukey_'$id

  local h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)

  local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
  local s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  local token="$h64.$p64.$s"

  echo "  Testing bitcoin node... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/getbestblockhash)
  [ "${rc}" -ne "200" ] && return 300

  echo "***** Bitcoin node rocks!" > /dev/console

  return 0
}

checklnnode() {
  echo ; echo "Testing Lightning..." > /dev/console
  local rc
  local id="002"
  local k
  eval k='$ukey_'$id

  local h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)

  local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
  local s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
  local token="$h64.$p64.$s"

  echo "  Testing LN node... " > /dev/console
  rc=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" --cacert /cert.pem https://gatekeeper/ln_getinfo)
  [ "${rc}" -ne "200" ] && return 400

  echo "***** LN node rocks!" > /dev/console

  return 0
}

checkservice() {
  echo ; echo "Testing if Cyphernode is up and running... I will keep trying during up to 5 minutes to give time to Docker to deploy everything..." > /dev/console

  local outcome
  local returncode=0
  local endtime=$(($(date +%s) + 300))
  local result

  while :
  do
    outcome=0
    for container in gatekeeper proxy proxycron pycoin <%= (features.indexOf('otsclient') != -1)?'otsclient ':'' %>bitcoin  <%= (features.indexOf('lightning') != -1)?'lightning ':'' %>; do
      echo "  Verifying ${container}..." > /dev/console
      (ping -c 10 ${container} | grep "0% packet loss" > /dev/null) &
      eval ${container}=$!
    done
    for container in gatekeeper proxy proxycron pycoin <%= (features.indexOf('otsclient') != -1)?'otsclient ':'' %>bitcoin  <%= (features.indexOf('lightning') != -1)?'lightning ':'' %>; do
      eval wait '$'${container} ; returncode=$? ; outcome=$((${outcome} + ${returncode}))
      eval c_${container}=${returncode}
    done

    # If '0% packet loss' everywhere or 5 minutes passed, we get out of this loop
    ([ "${outcome}" -eq "0" ] || [ $(date +%s) -gt ${endtime} ]) && break

    sleep 5
  done

  #  "containers": {
  #    "gatekeeper":true,
  #    "proxy":true,
  #    "proxycron":true,
  #    "pycoin":true,
  #    "otsclient":true,
  #    "bitcoin":true,
  #    "lightning":true
  #  }
  for container in gatekeeper proxy proxycron pycoin <%= (features.indexOf('otsclient') != -1)?'otsclient ':'' %>bitcoin  <%= (features.indexOf('lightning') != -1)?'lightning ':'' %>; do
    echo "  Analyzing ${container} results..." > /dev/console
    [ -n "${result}" ] && result="${result},"
    result="${result}\"${container}\":"
    eval "returncode=\$c_${container}"
    if [ "${returncode}" -eq "0" ]; then
      result="${result}true"
    else
      result="${result}false"
    fi
  done

  result="\"containers\":{${result}}"

  echo $result

  return ${outcome}
}

# /proxy/installation.json will contain something like that:
#{
#  "containers": {
#    "gatekeeper":true,
#    "proxy":true,
#    "proxycron":true,
#    "pycoin":true,
#    "otsclient":true,
#    "bitcoin":true,
#    "lightning":true
#  },
#  "features": {
#    "gatekeeper":true,
#    "pycoin":true,
#    "otsclient":true,
#    "bitcoin":true,
#    "lightning":true
#  }
#}

# Let's first see if everything is up.

result=$(checkservice)
returncode=$?
if [ "${returncode}" -ne "0" ]; then
  echo "xxxxx Cyphernode could not fully start properly within 5 minutes." > /dev/console
else
  echo "***** Cyphernode seems to be correctly deployed.  Let's run more thourough tests..." > /dev/console
fi

# Let's now check each feature fonctionality...
#  "features": {
#    "gatekeeper":true,
#    "pycoin":true,
#    "otsclient":true,
#    "bitcoin":true,
#    "lightning":true
#  }

result="${result},\"features\":{\"gatekeeper\":"
checkgatekeeper
returncode=$?
[ "${returncode}" -eq "0" ] && result="${result}true"
[ "${returncode}" -ne "0" ] && result="${result}false" && echo "xxxxx Gatekeeper error!" > /dev/console

result="${result},\"pycoin\":"
checkpycoin
returncode=$?
[ "${returncode}" -eq "0" ] && result="${result}true"
[ "${returncode}" -ne "0" ] && result="${result}false" && echo "xxxxx Pycoin error!" > /dev/console

<% if (features.indexOf('otsclient') != -1) { %>
result="${result},\"otsclient\":"
checkots
returncode=$?
[ "${returncode}" -eq "0" ] && result="${result}true"
[ "${returncode}" -ne "0" ] && result="${result}false" && echo "xxxxx OTSclient error!" > /dev/console
<% } %>

result="${result},\"bitcoin\":"
checkbitcoinnode
returncode=$?
[ "${returncode}" -eq "0" ] && result="${result}true"
[ "${returncode}" -ne "0" ] && result="${result}false" && echo "xxxxx Bitcoin error!" > /dev/console

<% if (features.indexOf('lightning') != -1) { %>
result="${result},\"lightning\":"
checklnnode
returncode=$?
[ "${returncode}" -eq "0" ] && result="${result}true"
[ "${returncode}" -ne "0" ] && result="${result}false" && echo "xxxxx Lightning error!" > /dev/console
<% } %>

result="{${result}}}"

echo "${result}" > /proxy/installation.json

echo ; echo "Tests finished." > /dev/console
