#!/bin/sh

. ${DB_PATH}/config.sh

send_to_wasabi_prod() {
  trace "Entering send_to_wasabi_prod()..."

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

random_wasabi_index() {
  trace "Entering random_wasabi_index()..."

  echo $(( $(od -An -N2 < /dev/urandom) % ${WASABI_INSTANCE_COUNT} ))
}

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
  if [ "$?" -ne "0" ] || [ -z ${label} ]; then
    # label tag null, so there's no label
    label='"unknown"'
  fi
  trace "[wasabi_newaddr] label=${label}"

  response=$(send_to_wasabi_prod $(random_wasabi_index) getnewaddress "[${label}]")
  returncode=$?
  trace_rc ${returncode}

  echo "${response}"

  return $?
}

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

  local index
  index=$(echo "${request}" | jq -er ".id")
  if [ "$?" -ne "0" ]; then
    # id tag null, let's check all instances
    index=
  fi
  trace "[wasabi_get_balance] index=${index}"

  local private
  private=$(echo "${request}" | jq -er ".private")
  if [ "$?" -ne "0" ]; then
    # private tag null, let's default to false
    private="false"
  fi
  trace "[wasabi_get_balance] private=${private}"

  local response
  local balance=0

  # wasabi rpc: listunspentcoins

  # sum up all result array amount fields, private and non private
  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ -n "${index}" ]; then
    minInstanceIndex=$index
    maxInstanceIndex=$index
  fi

  trace "[wasabi_get_balance] minInstanceIndex=${minInstanceIndex}"
  trace "[wasabi_get_balance] maxInstanceIndex=${maxInstanceIndex}"

  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    response=$(send_to_wasabi_prod ${i} listunspentcoins "[]")
#    trace "[wasabi_get_balance] response=${response}"
    if [ "${private}" = "true" ]; then
      balance=$((${balance}+$(echo "${response}" | jq ".result | map(select(.anonymitySet > ${WASABI_MIXUNTIL}) | .amount) | add")))
    else
      balance=$((${balance}+$(echo "${response}" | jq ".result | map(.amount) | add")))
    fi
    trace "[wasabi_get_balance] balance=${balance}"
  done

  echo "{\"balance\":${balance}}"

  return 0
}

wasabi_batchprivatetospender() {
  trace "Entering wasabi_batchprivatetospender()..."

  # Get spender newaddress
  # Get list of UTXO with anonymityset > configured threshold
  # Add amounts
  # Call spend

}

build_utxo_to_spend() {

  # build_utxo_to_spend <amount> <anonset> [id]
  # build_utxo_to_spend 72873 33

  local amount=${1}
  local anonset=${2}
  local id=${3}
  trace "[build_utxo_to_spend] amount=${amount}"
  trace "[build_utxo_to_spend] anonset=${anonset}"
  trace "[build_utxo_to_spend] id=${id}"

  local utxo
  local response

  # curl -s -u "wasabi:CHANGEME" -d '{"jsonrpc":"2.0","id":"1","method":"listunspentcoins","params":[]}' http://wasabi_0:18099/ | jq ".result | map(select(.anonymitySet > 25))"
  response=$(send_to_wasabi_prod ${id} listunspentcoins "[]")
  utxo=$(echo "${response}" | jq -Marc ".result | map(select(.anonymitySet > ${anonset}))")

  # from...
  # [{"txid":"f344bb3b62175a4f5ce7193cdf1e661b3dafe1ffe6a41c283be231cd2f70b6d8","index":1,"amount":1040365,"anonymitySet":29,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/1/720","address":"tb1qdytlanjjw9q7a86tsn8rwnhrn96yjvmu33h374"},{"txid":"cf09568720fdeecff3408c9ddd7868d2e072b104ce27069d854ac741303cc5de","index":1,"amount":1040749,"anonymitySet":28,"confirmed":true,"label":"ZeroLink Mixed Coin","keyPath":"84'/0'/0'/1/715","address":"tb1q3wepep4apqvcjg0n9ajn9eng4h57advysez658"}]
  # to...
  # [{"transactionid":"f344bb3b62175a4f5ce7193cdf1e661b3dafe1ffe6a41c283be231cd2f70b6d8", "index":1},{"transactionid":"cf09568720fdeecff3408c9ddd7868d2e072b104ce27069d854ac741303cc5de", "index":1}]

#  for 

}

wasabi_spend() {
  trace "Entering wasabi_spend()..."

  # wasabi rpc: spend

  # args:
  # - id: integer, optional
  # - private: boolean, optional, default=false
  # - address: string, required
  # - amount: number, required
}

wasabi_spend() {
  trace "Entering wasabi_spend()..."

  # wasabi rpc: spend

  # args:
  # - id: integer, optional
  # - private: boolean, optional, default=false
  # - address: string, required
  # - amount: number, required

  local response

  # curl -s -d '{"jsonrpc":"2.0","id":"1","method":"send", "params": { "sendto": "tb1qjlls57n6kgrc6du7yx4da9utdsdaewjg339ang", "coins":[{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0}], "amount": 15000, "label": "test transaction", "feeTarget":2 }}' http://wasabi_0:18099/
  response=$(send_to_wasabi_prod ${i} send "{}")

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
# curl -s -d '{"jsonrpc":"2.0","id":"1","method":"send", "params": { "sendto": "tb1qjlls57n6kgrc6du7yx4da9utdsdaewjg339ang", "coins":[{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0}], "amount": 15000, "label": "test transaction", "feeTarget":2 }}' http://wasabi_0:18099/
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

