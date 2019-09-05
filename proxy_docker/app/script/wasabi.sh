#@IgnoreInspection BashAddShebang

. ${DB_PATH}/config.sh

#WASABI_RPCUSER=<%= wasabi_rpcuser %>
#WASABI_RPCPASSWORD=<%= wasabi_rpcpassword %>
#WASABI_INSTANCE_COUNT=<%= wasabi_instance_count %>
#WASABI_DATAPATH=<%= wasabi_datapath %>

send_to_wasabi_prod() {
  trace "Entering send_to_wasabi_prod()..."

  local index=$1 # instance index
  trace "[send_to_wasabi] index=${index}"

  local method=$2 # method
  trace "[send_to_wasabi] method=${method}"

  local params=$3 # json string escaped
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

send_to_wasabi() {
  trace "Entering send_to_wasabi()..."

  local index=$1 # instance index
  trace "[send_to_wasabi] index=${index}"

  local method=$2 # method
  trace "[send_to_wasabi] method=${method}"

  local params=$3 # json string escaped
  trace "[send_to_wasabi] params=${params}"

  if [ "$#" -ne 3 ]; then
      echo "Wrong number of arguments"
      return 1
  fi

  if [ ! $index -lt "${WASABI_INSTANCE_COUNT}" ]; then
    echo "No such wasabi instance ${index}"
    return 1
  fi

  if [ "$method" = "getnewaddress" ]; then
    cat ././../../../wasabi_docker/newaddr.json
  elif [ "$method" = "listunspentcoins" ]; then
    cat ././../../../wasabi_docker/listunspentcoins.json
  fi
  return $?
}

random_wasabi_index() {
  trace "Entering random_wasabi_index()..."

  echo $(( $(od -An -N2 < /dev/urandom) % ${WASABI_INSTANCE_COUNT} ))
}

wasabi_newaddr() {
  trace "Entering wasabi_newaddr()..."

  # wasabi rpc: getnewaddress
  # args:
  # - {"label":"Pay #12 for 2018"}

  # queries random instance for a new bech32 address
  # returns {"jsonrpc":"2.0","result":{"address":"tb1qpgpe7mdhdpgz6894vl5a2rhvhukwjc35h99rqc","keyPath":"84'/0'/0'/0/24","label":"blah","publicKey":"024eaa964530e5a72059951cdab8d22c5df7543536b011a8bab85bc1f6089654d9","p2wpkh":"00140a039f6db768502d1cb567e9d50eecbf2ce96234"},"id":"12"}
  local request=${1}
  trace "[wasabi_newaddr] request=${request}"
  local label
  label=$(echo "${request}" | jq -e ".label")
  if [ "$?" -ne "0" ]; then
    # label tag null, so there's no label
    label="unknown"
  fi
  trace "[wasabi_newaddr] label=${label}"

  send_to_wasabi_prod $(random_wasabi_index) getnewaddress "[${label}]" | jq '.result'
  return $?
}

wasabi_get_balance() {
  trace "Entering wasabi_get_balance()..."

  local private=$1
  local index=$2

  # wasabi rpc: listunspentcoins

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

  # sum up all result array amount fields, private and non private
  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ $index ]; then
    minInstanceIndex=$index
    maxInstanceIndex=$index
  fi

  local sum=10

  # for ((index=minInstanceIndex;index<=maxInstanceIndex;index++)); do
  #   balance=$(send_to_wasabi ${index} listunspentcoins '{}' | jq 'reduce .result[].amount as $x (0; . + $x)')
  #   echo $index $sum $balance
  #   sum=$((sum + balance))
  # done

  jq -n --arg b "$balance" '.balance=$b'

}

wasabi_spend() {
  trace "Entering wasabi_spend()..."

  # wasabi rpc: spend

  # args:
  # - id: integer, required
  # - private: boolean, optional, default=false
  # - address: string, required
  # - amount: number, required
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
