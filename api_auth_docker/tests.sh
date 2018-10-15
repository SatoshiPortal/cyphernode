#!/bin/sh

# We just want to test the authentication/authorization, not the actual called function
# Replace
#   proxy_pass http://cyphernode:8888;
# by
#   proxy_pass http://tests:8888;
# in /etc/nginx/conf.d/default.conf to run the tests

test_expiration()
{
	# Let's test expiration: 1 second in payload, request 2 seconds later

	local id=${1}
#	echo "id=${id}"
	local k
	eval k='$ukey_'$id

	local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+1))}" | base64)
	local s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
	local token="$h64.$p64.$s"

	echo "  Sleeping 2 seconds... "
	sleep 2

	local rc
	echo -n "  Testing expired request... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getblockinfo)
	[ "${rc}" -ne "403" ] && return 10

	return 0
}

test_authentication()
{
	# Let's test authentication/signature

	local id=${1}
#	echo "id=${id}"
	local k
	eval k='$ukey_'$id

	local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
	local s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
	local token="$h64.$p64.$s"

	local rc

	echo -n "  Testing good signature... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getblockinfo)
	[ "${rc}" -eq "403" ] && return 20

	token="$h64.$p64.a$s"
	echo -n "  Testing bad signature... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getblockinfo)
	[ "${rc}" -ne "403" ] && return 30

	return 0
}

test_authorization_watcher()
{
	# Let's test autorization

	local id=${1}
#	echo "id=${id}"
	local k
	eval k='$ukey_'$id

	local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
	local s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
	local token="$h64.$p64.$s"

	local rc

	# Watcher can:
	# watch
	echo -n "  Testing watch... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/watch)
	[ "${rc}" -eq "403" ] && return 40

	# unwatch
	echo -n "  Testing unwatch... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/unwatch)
	[ "${rc}" -eq "403" ] && return 50

	# getactivewatches
	echo -n "  Testing getactivewatches... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getactivewatches)
	[ "${rc}" -eq "403" ] && return 60

	# getbestblockhash
	echo -n "  Testing getbestblockhash... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getbestblockhash)
	[ "${rc}" -eq "403" ] && return 70

	# getbestblockinfo
	echo -n "  Testing getbestblockinfo... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getbestblockinfo)
	[ "${rc}" -eq "403" ] && return 80

	# getblockinfo
	echo -n "  Testing getblockinfo... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getblockinfo)
	[ "${rc}" -eq "403" ] && return 90

	# gettransaction
	echo -n "  Testing gettransaction... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/gettransaction)
	[ "${rc}" -eq "403" ] && return 100

	# ln_getinfo
	echo -n "  Testing ln_getinfo... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/ln_getinfo)
	[ "${rc}" -eq "403" ] && return 110

	# ln_create_invoice
	echo -n "  Testing ln_create_invoice... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/ln_create_invoice)
	[ "${rc}" -eq "403" ] && return 120

	return 0
}

test_authorization_spender()
{
	# Let's test autorization

	local id=${1}
#	echo "id=${id}"
	local is_spender=${2}
#	echo "is_spender=${is_spender}"
	local k
	eval k='$ukey_'$id

	local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
	local s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
	local token="$h64.$p64.$s"

	local rc

	# Spender can do what the watcher can do, plus:
	# getbalance
	echo -n "  Testing getbalance... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getbalance)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 130
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 135

	# getnewaddress
	echo -n "  Testing getnewaddress... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/getnewaddress)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 140
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 145

	# spend
	echo -n "  Testing spend... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/spend)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 150
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 155

	# addtobatch
	echo -n "  Testing addtobatch... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/addtobatch)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 160
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 165

	# batchspend
	echo -n "  Testing batchspend... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/batchspend)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 170
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 175

	# deriveindex
	echo -n "  Testing deriveindex... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/deriveindex)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 180
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 185

	# derivepubpath
	echo -n "  Testing derivepubpath... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/derivepubpath)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 190
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 195

	# ln_pay
	echo -n "  Testing ln_pay... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/ln_pay)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 200
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 205

	# ln_newaddr
	echo -n "  Testing ln_newaddr... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/ln_newaddr)
	[ ${is_spender} = true ] && [ "${rc}" -eq "403" ] && return 210
	[ ${is_spender} = false ] && [ "${rc}" -ne "403" ] && return 215

	return 0
}

test_authorization_internal()
{
	# Let's test autorization

	local id=${1}
#	echo "id=${id}"
	local k
	eval k='$ukey_'$id

	local p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64)
	local s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
	local token="$h64.$p64.$s"

	local rc

	# Should be called from inside the Swarm:
	# conf
	echo -n "  Testing conf... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/conf)
	[ "${rc}" -ne "403" ] && return 220

	# executecallbacks
	echo -n "  Testing executecallbacks... "
	rc=$(time -f "%E" curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" -k https://localhost/executecallbacks)
	[ "${rc}" -ne "403" ] && return 230

	return 0
}

kapi_id="001";kapi_key="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";kapi_groups="watcher";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
kapi_id="003";kapi_key="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";kapi_groups="watcher,spender";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
kapi_id="005";kapi_key="6c009201b123e8c24c6b74590de28c0c96f3287e88cac9460a2173a53d73fb87";kapi_groups="watcher,spender,admin";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)

# Let's test expiration: 1 second in payload, request 2 seconds later

echo 'test_expiration "001"'
test_expiration "001" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_expiration "003"'
test_expiration "003" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_expiration "005"'
test_expiration "005" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc

# Let's test authentication/signature

echo 'test_authentication "001"'
test_authentication "001" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authentication "003"'
test_authentication "003" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authentication "005"'
test_authentication "005" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc

# Let's test autorization for watcher actions

echo 'test_authorization_watcher "001"'
test_authorization_watcher "001" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authorization_watcher "003"'
test_authorization_watcher "003" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authorization_watcher "005"'
test_authorization_watcher "005" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc

# Let's test autorization for spender actions

echo 'test_authorization_spender "001" false'
test_authorization_spender "001" false ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authorization_spender "003" true'
test_authorization_spender "003" true ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authorization_spender "005" true'
test_authorization_spender "005" true ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc

# Let's test autorization for admin actions

#test_authorization_admin "001"
#test_authorization_admin "003"
#test_authorization_admin "005"

# Let's test autorization for internal actions
echo 'test_authorization_internal "001"'
test_authorization_internal "001" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authorization_internal "003"'
test_authorization_internal "003" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
echo 'test_authorization_internal "005"'
test_authorization_internal "005" ; rc=$? ; [ $rc -ne 0 ] && echo $rc && return $rc
