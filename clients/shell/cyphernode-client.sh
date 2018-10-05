#!/bin/sh

. .cyphernode.conf

invoke_cyphernode()
{
	local action=${1}
	local post=${2}

	local h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)
	local p64=$(echo "{\"id\":\"${id}\",\"exp\":$((`date +"%s"`+10))}" | base64)
	local s=$(echo "$h64.$p64" | openssl dgst -hmac "$key" -sha256 -r | cut -sd ' ' -f1)
	local token="$h64.$p64.$s"

	if [ -n "${post}" ]; then
		echo $(curl -v -H "Authorization: Bearer $token" -d "${post}" -k "https://cyphernode/${action}")
		return $?
	else
		echo $(curl -v -H "Authorization: Bearer $token" -k "https://cyphernode/${action}")
		return $?
	fi
}

watch()
{
	# BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.122.233:1111/callback0conf","confirmedCallbackURL":"192.168.122.233:1111/callback1conf"}
	local btcaddr=${1}
	local cb0conf=${2}
	local cb1conf=${3}
	local post="{\"address\":\"${btcaddr}\",\"unconfirmedCallbackURL\":\"${cb0conf}\",\"confirmedCallbackURL\":\"${cb1conf}\"}"

	echo $(invoke_cyphernode "watch" ${post})
}

unwatch()
{
	# 192.168.122.152:8080/unwatch/2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp
	local btcaddr=${1}

	echo $(invoke_cyphernode "unwatch/${btcaddr}")
}

getactivewatches()
{
	# 192.168.122.152:8080/getactivewatches
	echo $(invoke_cyphernode "getactivewatches")
}

gettransaction()
{
	# http://192.168.122.152:8080/gettransaction/af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648
	local txid=${1}

	echo $(invoke_cyphernode "gettransaction/${txid}")
}

spend()
{
	# BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
	local btcaddr=${1}
	local amount=${2}
	local post="{\"address\":\"${btcaddr}\",\"amount\":\"${amount}\"}"

	echo $(invoke_cyphernode "spend" ${post})
}

getbalance()
{
	# http://192.168.122.152:8080/getbalance
	echo $(invoke_cyphernode "getbalance")
}

getnewaddress()
{
	# http://192.168.122.152:8080/getnewaddress
	echo $(invoke_cyphernode "getnewaddress")
}
