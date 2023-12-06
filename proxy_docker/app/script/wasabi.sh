#!/bin/sh

. walletoperations.sh

. ${DB_PATH}/config.sh

# send_to_wasabi <instance_nb> <rpc_method> <params>
# returns wasabi rpc response as is
send_to_wasabi() {
  trace "Entering send_to_wasabi()..."

  local returncode
  local index=$1 # instance index
  local method=$2 # method
  local params=$3 # json string escaped
  trace "[send_to_wasabi] index=${index}"
  trace "[send_to_wasabi] method=${method}"
  trace "[send_to_wasabi] params=${params}"

  local response

  if [ "$#" -ne 3 ]; then
      echo "Wrong number of arguments"
      return 1
  fi

  if [ ! $index -lt "${WASABI_INSTANCE_COUNT}" ]; then
    echo "No such wasabi instance ${index}"
    return 1
  fi

  trace "[send_to_wasabi] curl --config ${WASABI_RPC_CFG} -s -d \"{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"${method}\",\"params\":${params}}\" http://wasabi_${index}:18099/"
  response=$(curl --config ${WASABI_RPC_CFG} -s -d "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"${method}\", \"params\":${params}}" http://wasabi_${index}:18099/)
  returncode=$?
  trace_rc ${returncode}
  trace "[send_to_wasabi] response=${response}"

  echo "${response}"
  return $?
}

# random_wasabi_index
# returns random n between 0 and WASABI_INSTANCE_COUNT
random_wasabi_index() {
  trace "Entering random_wasabi_index()..."

  echo $(( $(od -An -N2 < /dev/urandom) % ${WASABI_INSTANCE_COUNT} ))
}

# wasabi_newaddr [requesthandler_request_string]
# requesthandler_request_string: JSON object with a "label" property: {"label":"Pay #12 for 2018"}
# returns wasabi rpc response as is
wasabi_newaddr() {
  trace "Entering wasabi_newaddr()..."

  # wasabi rpc: getnewaddress
  # optional args:
  # - {"label":"Pay #12 for 2018"}

  # queries random instance for a new bech32 address
  # returns {"jsonrpc":"2.0","result":{"address":"tb1qpgpe7mdhdpgz6894vl5a2rhvhukwjc35h99rqc","keyPath":"84'/0'/0'/0/24","label":"blah","publicKey":"024eaa964530e5a72059951cdab8d22c5df7543536b011a8bab85bc1f6089654d9","p2wpkh":"00140a039f6db768502d1cb567e9d50eecbf2ce96234"},"id":"12"}

  local returncode
  local request=${1}
  trace "[wasabi_newaddr] request=${request}"
  local response
  local label
  label=$(echo "${request}" | jq -e ".label")
  if [ "$?" -ne "0" ] || [ -z "${label}" ]; then
    # label tag null, so there's no label
    label='"unknown"'
  fi
  trace "[wasabi_newaddr] label=${label}"

  response=$(send_to_wasabi $(random_wasabi_index) getnewaddress "[${label}]")
  returncode=$?
  trace_rc ${returncode}

  # response={"jsonrpc":"2.0","result":{"address":"tb1qzurfz22v3ayx4kfex2q9hf2u253p55cdrqtr3t","keyPath":"84'/0'/0'/0/29","label":["Order #10015"],"publicKey":"03113ba8f1e525ee2aa4a73dd72ea587529ab29776f9573fc4edadd47cc12e0ffc","p2wpkh":"0014170691294c8f486ad93932805ba55c55221a530d"},"id":"0"}
  response=$(echo ${response} | jq -Mac '.result | {"address":"\(.address)","keyPath":"\(.keyPath)","label":"\(.label)"}')
  # response={"address":"tb1qzurfz22v3ayx4kfex2q9hf2u253p55cdrqtr3t","keyPath":"84'/0'/0'/0/29","label":["Order #10015"]}
  trace "[wasabi_newaddr] response=${response}"

  echo "${response}"

  return $?
}

# wasabi_get_balance <request>
# request: JSON object with "id" and/or "private" properties: {"id":1,"private":true}
# id: wasabi instance id, optional.  If not supplied, will add every instance balances
# private: boolean, returns mixed balance only (anonymitySet > threshold) or not.  Default false.
# returns balance in sats: {"balance":872634}
wasabi_get_balance() {
  trace "Entering wasabi_get_balance()..."

  # args:
  # - id: integer, optional
  # - private: boolean, optional, default=false
  # returns the total balance of either
  # - all wasabi instances
  # - a single instance, when provide with an id
  # takes a 'private' flag. if 'private' flag is set
  # the balance will only return the unspent outputs
  # which have an anon set of at least what is configured.
  # if id is defined, it will return the balance of
  # the wasabi instance with id <id>, else it will
  # return the balance of all instances

  # {"id":1,"private":true}
  # {"private":true}
  # {}

  # Tests:
  # /proxy # curl -s -d "" proxy:8888/wasabi_getbalance | jq ".balance" ; echo $(($(curl -s -d "{\"id\":\"0\"}" proxy:8888/wasabi_getbalance | jq ".balance")+$(curl -s -d "{\"id\":\"1\"}" proxy:8888/wasabi_getbalance | jq ".balance")))
  # 200650200
  # 200650200
  # /proxy # curl -s -d "{\"private\":true}" proxy:8888/wasabi_getbalance | jq ".balance" ; echo $(($(curl -s -d "{\"id\":\"0\",\"private\":true}" proxy:8888/wasabi_getbalance | jq ".balance")+$(curl -s -d "{\"id\":\"1\",\"private\":true}" proxy:8888/wasabi_getbalance | jq ".balance")))
  # 180653937
  # 180653937

  local request=${1}

  local instanceid
  instanceid=$(echo "${request}" | jq -er ".id")
  if [ "$?" -ne "0" ]; then
    # id tag null, let's check all instances
    instanceid=
  fi
  trace "[wasabi_get_balance] instanceid=${instanceid}"

  local private
  private=$(echo "${request}" | jq -er ".private")
  if [ "$?" -ne "0" ]; then
    # private tag null, let's default to false
    private="false"
  fi
  trace "[wasabi_get_balance] private=${private}"

  local response
  local balance=0
  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ -n "${instanceid}" ]; then
    minInstanceIndex=$instanceid
    maxInstanceIndex=$instanceid
  fi

  trace "[wasabi_get_balance] minInstanceIndex=${minInstanceIndex}"
  trace "[wasabi_get_balance] maxInstanceIndex=${maxInstanceIndex}"

  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    # wasabi rpc: listunspentcoins
    response=$(send_to_wasabi ${i} listunspentcoins "[]")
#    trace "[wasabi_get_balance] response=${response}"
    if [ "${private}" = "true" ]; then
      balance=$((${balance}+$(echo "${response}" | jq ".result | map(select(.anonymitySet >= ${WASABI_MIXUNTIL}) | .amount) | add")))
    else
      balance=$((${balance}+$(echo "${response}" | jq ".result | map(.amount) | add")))
    fi
    trace "[wasabi_get_balance] balance=${balance}"
  done

  echo "{\"balance\":${balance},\"instanceid\":\"${instanceid}\",\"private\":${private}}"

  return 0
}

# wasabi_batchprivatetospender
# Will send all mixed coins (with anonymitySet > threshold) to spending wallet.
wasabi_batchprivatetospender() {
  trace "Entering wasabi_batchprivatetospender()..."

  local response
  local returncode
  local instanceid=0
  local amount=0

  # Get spender newaddress
  local toaddress
  local utxo_to_spend
  local balance

  for instanceid in `seq 0 $((WASABI_INSTANCE_COUNT-1))`
  do
    # Get list of UTXO with anonymityset > configured threshold
    # build_utxo_to_spend <spendingAmount> <anonset> <instanceid>
    utxo_to_spend=$(build_utxo_to_spend 0 ${WASABI_MIXUNTIL} ${instanceid})
    # Amount is prefixed to utxostring, let's consider it
    amount=$(echo "${utxo_to_spend}" | cut -d '[' -f1)
    trace "[wasabi_batchprivatetospender] amount=${amount}"

    if [ "${amount}" -gt "0" ]; then
      trace "[wasabi_batchprivatetospender] We have mixed coins ready to consume!"

      toaddress=$(getnewaddress | jq ".address")
      trace "[wasabi_batchprivatetospender] toaddress=${toaddress}"

      utxo_to_spend="[$(echo "${utxo_to_spend}" | cut -d '[' -f2)"
      trace "[wasabi_batchprivatetospender] utxo_to_spend=${utxo_to_spend}"
    #  balance=$(wasabi_get_balance "{\"id\":${instanceid},\"private\":true}")
    #  trace "[wasabi_batchprivatetospender] balance=${balance}"

      # Call spend
      response=$(send_to_wasabi ${instanceid} send "{\"payments\":[{\"sendto\":${toaddress},\"amount\":${amount},\"label\":\"tx\",\"subtractFee\":true}],\"coins\":${utxo_to_spend},\"feeTarget\":2}")
      returncode=$?
      trace_rc ${returncode}
    else
      trace "[wasabi_batchprivatetospender] NO mixed coins to spend!"
    fi
  done
}

# build_utxo_to_spend <spendingAmount> <anonset> <instanceid>
build_utxo_to_spend() {
  trace "Entering build_utxo_to_spend()..."

  # build_utxo_to_spend <amount> <anonset> [id]
  # build_utxo_to_spend 72873 33

  local spendingAmount=${1}
  local anonset=${2}
  local instanceid=${3}
  trace "[build_utxo_to_spend] spendingAmount=${spendingAmount}"
  trace "[build_utxo_to_spend] anonset=${anonset}"
  trace "[build_utxo_to_spend] instanceid=${instanceid}"

  local utxo
  local nbUtxo
  local response
  local builtUtxo
  local amounts

  # curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"listunspentcoins","params":[]}' http://wasabi_0:18099/ | jq ".result | map(select(.anonymitySet > 25))"
  response=$(send_to_wasabi ${instanceid} listunspentcoins "[]")
  #utxos=$(echo "${response}" | jq -Mac ".result[] | select(.anonymitySet >= ${anonset}) | [.txid, .index, .amount]")
  utxos=$(echo "${response}" | jq -Mac ".result[] | select(.anonymitySet >= ${anonset} and .confirmed) | {\"transactionId\": .txid,index}")
  trace "[build_utxo_to_spend] utxos=${utxos}"
  amounts=$(echo "${response}" | jq -Mac '.result[].amount')

#  nbUtxo=$(echo "${utxo}" | jq "length")

  # from...
  # [{"txid":"f344bb3b62175a4f5ce7193cdf1e661b3dafe1ffe6a41c283be231cd2f70b6d8","index":1,"amount":1040365,"anonymitySet":29,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/1/720","address":"tb1qdytlanjjw9q7a86tsn8rwnhrn96yjvmu33h374"},{"txid":"cf09568720fdeecff3408c9ddd7868d2e072b104ce27069d854ac741303cc5de","index":1,"amount":1040749,"anonymitySet":28,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/1/715","address":"tb1q3wepep4apqvcjg0n9ajn9eng4h57advysez658"}]
  # to...
  # [{"transactionid":"f344bb3b62175a4f5ce7193cdf1e661b3dafe1ffe6a41c283be231cd2f70b6d8", "index":1},{"transactionid":"cf09568720fdeecff3408c9ddd7868d2e072b104ce27069d854ac741303cc5de", "index":1}]

  # curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"listunspentcoins","params":[]}' http://wasabi_0:18099/ | jq -Mac ".result[] | select(.anonymitySet > 25) | [.txid, .index, .amount]"

  local txid
  local index
  local amount
  local n=1
  local totalAmount=0
  local IFS=$'\n'

  for utxo in ${utxos}
  do
#    txid=$(echo "${utxo}" | jq ".[0]")
#    index=$(echo "${utxo}" | jq ".[1]")
#    amount=$(echo "${utxo}" | jq ".[2]")
    amount=$(echo "${amounts}" | cut -d$'\n' -f$n)
    trace "[build_utxo_to_spend] amount=${amount}"
    n=$((n+1))
    trace "[build_utxo_to_spend] n=${n}"
#    trace "[build_utxo_to_spend] txid=${txid}"
#    trace "[build_utxo_to_spend] index=${index}"

    if [ -n "${builtUtxo}" ]; then
      builtUtxo="${builtUtxo},${utxo}"
    else
      builtUtxo="${utxo}"
    fi

#    builtUtxo="${builtUtxo}{\"transactionId\":${txid},\"index\":${index}}"
#    trace "[build_utxo_to_spend] builtUtxo=${builtUtxo}"

    totalAmount=$((totalAmount+amount))
    trace "[build_utxo_to_spend] totalAmount=${totalAmount}"

    # End when amount reached, or process all if spendingAmount supplied is 0
    [ "${spendingAmount}" -ne "0" ] && [ "${totalAmount}" -ge "${spendingAmount}" ] && break
  done

  # If not enough funds...
  [ "${spendingAmount}" -ne "0" ] && [ "${totalAmount}" -lt "${spendingAmount}" ] && return 1

  builtUtxo="${totalAmount}[${builtUtxo}]"
  trace "[build_utxo_to_spend] builtUtxo=${builtUtxo}"

  echo "${builtUtxo}"

  return 0
}

# wasabi_spend <requesthandler_request_string>
# requesthandler_request_string: JSON object with "id", "private", "amount" and "address" properties: {"id":1,"private":true,"amount":0.00103440,"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp"}
# id: optional.  Will use first instance with enough funds, if not supplied.
# returns wasabi rpc response as is
wasabi_spend() {
  trace "Entering wasabi_spend()..."

  # wasabi rpc: spend

  # args:
  # - id: integer, optional
  # - private: boolean, optional, default=false
  # - address: string, required
  # - amount: number, required

  # If no instance id supplied, will find the first with enough funds
  # There must be enough funds on at least one instance

  # {"id":1,"private":true,"amount":0.00103440,"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp"}

  local request=${1}
  local returncode
  local response

  local spendingAmount
  spendingAmount=$(echo "${request}" | jq -er ".amount")
  if [ "$?" -ne "0" ]; then
    # amount tag null but required
    trace "[wasabi_spend] spendingAmount is required"
    return 1
  fi
  trace "[wasabi_spend] spendingAmount=${spendingAmount}"

  local address
  address=$(echo "${request}" | jq -er ".address")
  if [ "$?" -ne "0" ]; then
    # address tag null but required
    trace "[wasabi_spend] address is required"
    return 1
  fi
  trace "[wasabi_spend] address=${address}"

  local instanceid
  instanceid=$(echo "${request}" | jq -er ".id")
  if [ "$?" -ne "0" ]; then
    # id tag null
    instanceid=
  fi
  trace "[wasabi_spend] instanceid=${instanceid}"

  local private
  private=$(echo "${request}" | jq -er ".private")
  if [ "$?" -ne "0" ]; then
    # private tag null
    private=false
  fi
  trace "[wasabi_spend] private=${private}"

  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ -n "${instanceid}" ]; then
    minInstanceIndex=$instanceid
    maxInstanceIndex=$instanceid
  fi

  trace "[wasabi_get_balance] minInstanceIndex=${minInstanceIndex}"
  trace "[wasabi_get_balance] maxInstanceIndex=${maxInstanceIndex}"

  local balance
  local i
  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    # {"id":1,"private":true}
    balance=$(wasabi_get_balance "{\"id\":\"$i\",\"private\":${private}}")
    returncode=$?
    trace_rc ${returncode}

    if [ "${returncode}" -eq "0" ]; then
      balance=$(echo "${balance}" | jq ".balance")
      if [ "${balance}" -ge "${spendingAmount}" ]; then
        instanceid=$i
        break
      fi
    fi
  done

  local utxostring
  if [ "${balance}" -ge "${spendingAmount}" ]; then
    utxostring=$(build_utxo_to_spend ${spendingAmount} ${WASABI_MIXUNTIL} ${instanceid})
    # Amount is prefixed to utxostring, let's remove it
    utxostring="[$(echo "${utxostring}" | cut -d '[' -f2)"

    # curl -s -d '{"jsonrpc":"2.0","id":"1","method":"send", "params": { "sendto": "tb1qjlls57n6kgrc6du7yx4da9utdsdaewjg339ang", "coins":[{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0}], "amount": 15000, "label": "test transaction", "feeTarget":2 }}' http://wasabi_0:18099/
    response=$(send_to_wasabi ${instanceid} send "{\"payments\":[{\"sendto\":\"${address}\",\"amount\":${spendingAmount},\"label\":\"tx\"}],\"coins\":${utxostring},\"feeTarget\":2}")
    returncode=$?
    trace_rc ${returncode}
  else
    response="{\"event\":\"wasabi_spend\",\"result\":\"error\",\"message\":\"Not enough funds\"}"
  fi

  echo ${response}

  return ${returncode}
}

wasabi_get_transactions() {
  trace "Entering wasabi_get_transactions()..."

  # No rpc call. Needs to be implemented

  # args:
  # - id: integer, optional
  # return all transactions of either one wasabi instance
  # or all instances, depending on the id parameter
}

# Getting an address:
#
# /app # curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"getnewaddress","params":["t1"]}' http://127.0.0.1:18099/ | jq
# {
#   "jsonrpc": "2.0",
#   "result": {
#     "address": "tb1qqw8jzztmausq000plz4myxpuqdmy5wgrrcj63j",
#     "keyPath": "84'/0'/0'/0/21",
#     "label": "t1",
#     "publicKey": "03cb77191ef66857227eba1f210ac7daaa308628dc072b0dae97f8fa25a8157461",
#     "p2wpkh": "0014038f21097bef2007bde1f8abb2183c03764a3903"
#   },
#   "id": "1"
# }
#
# Sending funds:
#
# mm01:dist kexkey$ docker exec -it 8a3 bitcoin-cli -rpcwallet=spending01.dat sendtoaddress tb1qqw8jzztmausq000plz4myxpuqdmy5wgrrcj63j 0.2
# a4ac6530d82fd16e724c1ed8082890bb9dd33bf817c3504ec6e2722aaaa92439
#
# unconfirmed utxo:
#
# /app # curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"listunspentcoins"}' http://127.0.0.1:18099/ | jq
# {
#   "jsonrpc": "2.0",
#   "result": [
#     {
#       "txid": "a4ac6530d82fd16e724c1ed8082890bb9dd33bf817c3504ec6e2722aaaa92439",
#       "index": 0,
#       "amount": 20000000,
#       "anonymitySet": 1,
#       "confirmed": false,
#       "label": "t1",
#       "keyPath": "84'/0'/0'/0/21",
#       "address": "tb1qqw8jzztmausq000plz4myxpuqdmy5wgrrcj63j"
#     }
#   ],
#   "id": "1"
# }
#

# confirmed utxo:
#
# /app # curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"listunspentcoins","params":[]}' http://127.0.0.1:18099/ | jq
# {
#   "jsonrpc": "2.0",
#   "result": [
#     {
#       "txid": "a4ac6530d82fd16e724c1ed8082890bb9dd33bf817c3504ec6e2722aaaa92439",
#       "index": 0,
#       "amount": 20000000,
#       "anonymitySet": 1,
#       "confirmed": true,
#       "label": "t1",
#       "keyPath": "84'/0'/0'/0/21",
#       "address": "tb1qqw8jzztmausq000plz4myxpuqdmy5wgrrcj63j"
#     }
#   ],
#   "id": "1"
# }

# for i in 0 1 2 3 4; do echo $i = $(curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"listunspentcoins","params":[]}' http://wasabi_$i:18099/); done

#
# How to get utxo with anonymitySet > 25
#
# curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"135","method":"listunspentcoins","params":[]}' http://wasabi_0:18099/ | jq ".result | map(select(.anonymitySet > 25))"
#
# How to add up amounts of utxo with anonymitySet > 25
#
# curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"135","method":"listunspentcoins","params":[]}' http://wasabi_0:18099/ | jq ".result | map(select(.anonymitySet > 25) | .amount) | add"
#

# Spend
#
# curl -s -d '{"jsonrpc":"2.0","id":"1","method":"send", "params": { "payments":[{"sendto": "tb1qjlls57n6kgrc6du7yx4da9utdsdaewjg339ang", "amount": 15000, "label": "test transaction"}], "coins":[{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0}], "feeTarget":2 }}' http://wasabi_0:18099/
#


# Wasabi management:
# - After rotating through the wasabi wallets for receiving addresses, we assume that there will be a randomized flow of coins coming in
# - after being mixed, some coins from one wallet are mixed with other coins from other wallets (including our own)
# - every time there is a new block, we look up the status of our utxos for any utxo which is above the anonymity set (e.g. 10). - we take the utxo of each of our wasabi wallets and we send it to the spender. We batch transactions together within each wallets when there is more than one input.
# - the spender will generate basically 3 receiving addresses (one per wasabi instance) each block
# - BONUS: we set a 4th wasabi wallet which receives the change from the Bitcoin core spender and sends it back every block. This requires us to play around with the Bitcoin core spender configs to set the xpub of the wasabi #4 (edited)
#
# francis  3 days ago
# It looks like a few utxos are leaking out of the coinjoin cycle randomly, much better than big clusters to one address

# [{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0},{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0},{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0}]


# {"jsonrpc":"2.0","result":[{"txid":"59356db335c19b2a7f55abd8e42bde10a171f5950ad65db83d7b7f0a2b28e42f","index":1,"amount":1780644,"anonymitySet":3,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/1/736","address":"tb1qepkmlaannyaz2mad6eh6cm55waw4namah9499f"},{"txid":"e6d8f0183d74fdee988c3072c9eb8c2263655de9fa38037f06e45adfedfdb806","index":0,"amount":1999460,"anonymitySet":3,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/144","address":"tb1qd0v6mswa4ldnr6l5kqsdaxww9lgf274kcydm4l"}],"id":"0"}
#
# from
#
# {"jsonrpc":"2.0","result":
# [
# {"txid":"59356db335c19b2a7f55abd8e42bde10a171f5950ad65db83d7b7f0a2b28e42f","index":1,"amount":1780644,"anonymitySet":3,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/1/736","address":"tb1qepkmlaannyaz2mad6eh6cm55waw4namah9499f"},
# {"txid":"e6d8f0183d74fdee988c3072c9eb8c2263655de9fa38037f06e45adfedfdb806","index":0,"amount":1999460,"anonymitySet":3,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/1/44","address":"tb1qd0v6mswa4ldnr6l5kqsdaxww9lgf274kcydm4l"}
# ],
# "id":"0"}
#
# to
#
# [{"transactionid":"59356db335c19b2a7f55abd8e42bde10a171f5950ad65db83d7b7f0a2b28e42f", "index":1},{"transactionid":"e6d8f0183d74fdee988c3072c9eb8c2263655de9fa38037f06e45adfedfdb806", "index":0}]
#
# jq -Mac ".result[] | select(.anonymitySet > 25) | [.txid, .index, .amount]"
#
# ["59356db335c19b2a7f55abd8e42bde10a171f5950ad65db83d7b7f0a2b28e42f",1,1780644]
# ["e6d8f0183d74fdee988c3072c9eb8c2263655de9fa38037f06e45adfedfdb806",0,1999460]
#
#
# echo '[{"a":1,"b":"aa"},{"a":5,"b":"bb"},{"a":6,"b":"cc"},{"a":3,"b":"dd"},{"a":9,"b":"ee"}]'
#



#curl -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"send", "params": { "payments":[{"sendto": "bcrt1q4vemf397tyuwdktqzhneux8r8v9dg65ydzgvla", "amount": 15000, "label": "test transaction", "subtractFee": true},{"sendto": "bcrt1q5jr80cyx62hhq5mhu8wa64jcamxytnr0lskm4g", "amount": 25000, "label": "test transaction", "subtractFee": true}], "coins":[{"transactionId":"117d79003bf2cab39d19181d366c481edb681c0cf326b7d06711755bb5e6db27","index":1}], "feeTarget":2 }}' http://wasabi_2:18099/

#[{"transactionId":"117d79003bf2cab39d19181d366c481edb681c0cf326b7d06711755bb5e6db27","index":1}]

#
# USEFUL
#
# docker exec -it `docker ps -q -f "name=cyphernode_proxy\."` sh -c 'for i in `seq 0 4`; do echo $i: $(curl -sd "{\"id\":$i,\"private\":false}" localhost:8888/wasabi_getbalance); done'
#
# docker exec -it `docker ps -q -f "name=cyphernode_proxy\."` sh -c 'for i in `seq 0 4`; do echo $i: $(curl -s -u "wasabi:CHANGEME" -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"getnewaddress\",\"params\":[\"a\"]}" http://wasabi_$i:18099/); done'
#
# docker exec -it `docker ps -q -f "name=cyphernode_proxy\."` sh -c 'for i in `seq 0 4`; do echo $i: $(curl -s -u "wasabi:CHANGEME" -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"listunspentcoins\",\"params\":[]}" http://wasabi_$i:18099/); done'
#
# docker exec -it `docker ps -q -f name=bitcoin` bitcoin-cli -rpcwallet=wasabi_backend.dat generatetoaddress 1 bcrt1qh6wf7mm67dyve2t7jwmpt5xv7h360feaxxa8cm
# while true; do docker exec -it `docker ps -q -f name=bitcoin` bitcoin-cli -rpcwallet=wasabi_backend.dat generatetoaddress 1 bcrt1qh6wf7mm67dyve2t7jwmpt5xv7h360feaxxa8cm; sleep 120; done
#
# for i in `docker stack ps -q -f name=cyphernode_wasabi cyphernode`; do echo -e "\n################################### $i:\n$(docker service logs --tail 40 $i)" ; done
#

# [{"desc":"hammer","color":"red","qty":4},{"desc":"screwdriver","color":"blue","qty":7},{"desc":"nail","color":"yellow","qty":40},{"desc":"screw","color":"pink","qty":30},{"desc":"plyer","color":"white","qty":3},{"desc":"gluetube","color":"black","qty":14}]
#
# 0-4: [{"desc":"hammer","color":"red","qty":4}]
# 5-11: [{"desc":"hammer","color":"red","qty":4},{"desc":"screwdriver","color":"blue","qty":7}]
# 12-51: [{"desc":"hammer","color":"red","qty":4},{"desc":"screwdriver","color":"blue","qty":7},{"desc":"nail","color":"yellow","qty":40}]
# 52-81: [{"desc":"hammer","color":"red","qty":4},{"desc":"screwdriver","color":"blue","qty":7},{"desc":"nail","color":"yellow","qty":40},{"desc":"screw","color":"pink","qty":30}]
# 82-84: [{"desc":"hammer","color":"red","qty":4},{"desc":"screwdriver","color":"blue","qty":7},{"desc":"nail","color":"yellow","qty":40},{"desc":"screw","color":"pink","qty":30},{"desc":"plyer","color":"white","qty":3}]
# 85-98: [{"desc":"hammer","color":"red","qty":4},{"desc":"screwdriver","color":"blue","qty":7},{"desc":"nail","color":"yellow","qty":40},{"desc":"screw","color":"pink","qty":30},{"desc":"plyer","color":"white","qty":3},{"desc":"gluetube","color":"black","qty":14}]
#

# ! /bin/bash
#JSON='[{"desc":"hammer","color":"red","qty":4},{"desc":"screwdriver","color":"blue","qty":7},{"desc":"nail","color":"yellow","qty":40},{"desc":"screw","color":"pink","qty":30},{"desc":"plyer","color":"white","qty":3},{"desc":"gluetube","color":"black","qty":14}]'

#CUSTOM_FILTERS="def addBucket(f): f | map( { g: ( (f.qty / 5) | floor *5 ), o: f} )"

#echo $JSON | jq "$CUSTOM_FILTERS; . | addBucket(.) | group_by(.g)"

# jq -Mac '.result[] | {"transactionId": .txid, index, amount}'
