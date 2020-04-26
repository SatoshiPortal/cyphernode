#!/bin/sh

#
# USEFUL
#
# docker exec -it `docker ps -q -f "name=cyphernode_proxy\."` sh -c 'for i in `seq 0 1`; do echo $i: $(curl -sd "{\"instanceId\":$i,\"private\":false}" localhost:8888/wasabi_getbalance); done'
# docker exec -it `docker ps -q -f "name=cyphernode_proxy\."` sh -c 'for i in `seq 0 1`; do echo $i: $(curl -sd "{\"instanceId\":$i}" localhost:8888/wasabi_getnewaddress); done'
#
# docker exec -it `docker ps -q -f "name=cyphernode_proxy\."` sh -c 'for i in `seq 0 1`; do echo $i: $(curl -s -u "wasabi:CHANGEME" -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"getnewaddress\",\"params\":[\"a\"]}" http://wasabi_$i:18099/); done'
#
# docker exec -it `docker ps -q -f "name=cyphernode_proxy\."` sh -c 'for i in `seq 0 1`; do echo $i: $(curl -s -u "wasabi:CHANGEME" -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"listunspentcoins\",\"params\":[]}" http://wasabi_$i:18099/); done'
#
# docker exec -it `docker ps -q -f name=bitcoin` bitcoin-cli -rpcwallet=wasabi_backend.dat generatetoaddress 1 bcrt1qh6wf7mm67dyve2t7jwmpt5xv7h360feaxxa8cm
# while true; do docker exec -it `docker ps -q -f name=bitcoin` bitcoin-cli -rpcwallet=wasabi_backend.dat generatetoaddress 1 bcrt1qh6wf7mm67dyve2t7jwmpt5xv7h360feaxxa8cm; sleep 120; done
#
# for i in `docker stack ps -q -f name=cyphernode_wasabi cyphernode`; do echo -e "\n################################### $i:\n$(docker service logs --tail 40 $i)" ; done
#

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
#  trace "[send_to_wasabi] params=${params}"

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
  return ${returncode}
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
  # - {"instanceId":0,"label":"Pay #12 for 2018"}

  # queries random instance for a new bech32 address
  # returns {"jsonrpc":"2.0","result":{"address":"tb1qpgpe7mdhdpgz6894vl5a2rhvhukwjc35h99rqc","keyPath":"84'/0'/0'/0/24","label":"blah","publicKey":"024eaa964530e5a72059951cdab8d22c5df7543536b011a8bab85bc1f6089654d9","p2wpkh":"00140a039f6db768502d1cb567e9d50eecbf2ce96234"},"id":"12"}

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
  local instanceid
  instanceid=$(echo "${request}" | jq -e ".instanceId")
  if [ "$?" -ne "0" ] || [ "${instanceid}" -ge "${WASABI_INSTANCE_COUNT}" ] || [ "${instanceid}" -lt "0" ]; then
    # instanceId tag null, so there's no instanceId
    trace "[wasabi_newaddr] instanceId not supplied or out of range, choosing a random one..."
    instanceid=$(random_wasabi_index)
  fi
  trace "[wasabi_newaddr] instanceid=${instanceid}"

  response=$(send_to_wasabi ${instanceid} getnewaddress "[${label}]")
  returncode=$?
  trace_rc ${returncode}

  # response={"jsonrpc":"2.0","result":{"address":"tb1qzurfz22v3ayx4kfex2q9hf2u253p55cdrqtr3t","keyPath":"84'/0'/0'/0/29","label":["Order #10015"],"publicKey":"03113ba8f1e525ee2aa4a73dd72ea587529ab29776f9573fc4edadd47cc12e0ffc","p2wpkh":"0014170691294c8f486ad93932805ba55c55221a530d"},"id":"0"}
  response=$(echo ${response} | jq -Mac '.result | {"address":"\(.address)","keyPath":"\(.keyPath)","label":"\(.label)"}')
  # response={"address":"tb1qzurfz22v3ayx4kfex2q9hf2u253p55cdrqtr3t","keyPath":"84'/0'/0'/0/29","label":["Order #10015"]}
  trace "[wasabi_newaddr] response=${response}"

  echo "${response}"

  return ${returncode}
}

# returns balance in sats: {"0":{"private":4100000,"total":12215179},"1":{"private":3600000,"total":20917754},"all":{"private":7700000,"total":33132933}}
wasabi_getbalances() {
  trace "Entering wasabi_getbalances()..."

  local returncode
  local response
  local balance=0
  local priv_bal=0
  local total=0
  local priv_total=0
  local balances
  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  trace "[wasabi_getbalances] WASABI_MIXUNTIL=${WASABI_MIXUNTIL}"

  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    # wasabi rpc: listunspentcoins
    response=$(send_to_wasabi ${i} listunspentcoins "[]")
    returncode=$?
    trace_rc ${returncode}

    if [ "${returncode}" -ne "0" ]; then
      return ${returncode}
    fi

    priv_bal=$(echo "${response}" | jq ".result | map(select(.anonymitySet >= ${WASABI_MIXUNTIL}) | .amount) | add")
    balance=$(echo "${response}" | jq ".result | map(.amount) | add")

    if [ "${priv_bal}" = "null" ]; then
      priv_bal=0
    fi
    trace "[wasabi_getbalances] priv_bal ${i}=${priv_bal}"

    priv_total=$((${priv_total}+${priv_bal}))
    trace "[wasabi_getbalances] priv_total=${priv_total}"

    if [ "${balance}" = "null" ]; then
      balance=0
    fi
    trace "[wasabi_getbalances] balance ${i}=${balance}"

    total=$((${total}+${balance}))
    trace "[wasabi_getbalances] total=${total}"

    if [ -z "${balances}" ]; then
      balances="\"${i}\":{\"private\":${priv_bal},\"total\":${balance}}"
    else
      balances="${balances},\"${i}\":{\"private\":${priv_bal},\"total\":${balance}}"
    fi
    trace "[wasabi_getbalances] balances=${balances}"
  done

  echo "{${balances},\"all\":{\"private\":${priv_total},\"total\":${total}}}"

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
      response=$(send_to_wasabi ${instanceid} send "{\"payments\":[{\"sendto\":${toaddress},\"amount\":${amount},\"label\":\"batchprivatetospender-auto-send\",\"subtractFee\":true}],\"coins\":${utxo_to_spend},\"feeTarget\":2,\"password\":\"\"}")
      returncode=$?
      trace_rc ${returncode}
      if [ "${returncode}" -ne "0" ]; then
        return ${returncode}
      fi
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

  response=$(send_to_wasabi ${instanceid} listunspentcoins "[]")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne "0" ]; then
    return ${returncode}
  fi

  # We only want mixed coins with correct minimum anonymitySet and we'll spend only the confirmed one to avoid problems.
  utxos=$(echo "${response}" | jq -Mac ".result[] | select(.anonymitySet >= ${anonset} and .confirmed) | {\"transactionId\": .txid,index}")
  trace "[build_utxo_to_spend] utxos=${utxos}"

  # We'll use this amount list to increase up to the amount to spend in the following loop.
  amounts=$(echo "${response}" | jq -Mac '.result[].amount')

  local txid
  local index
  local amount
  local n=1
  local totalAmount=0
  local IFS=$'\n'

  for utxo in ${utxos}
  do
    amount=$(echo "${amounts}" | cut -d$'\n' -f$n)
    trace "[build_utxo_to_spend] n=${n}, amount=${amount}"
    n=$((n+1))

    if [ -n "${builtUtxo}" ]; then
      builtUtxo="${builtUtxo},${utxo}"
    else
      builtUtxo="${utxo}"
    fi

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


  local request=${1}
  local returncode
  local response

  local spendingAmount
  spendingAmount=$(echo "${request}" | jq ".amount")
  if [ "${spendingAmount}" = "null" ]; then
    # amount tag null but required
    trace "[wasabi_spend] spendingAmount is required"
    return 1
  fi
  trace "[wasabi_spend] spendingAmount=${spendingAmount}"

  local address
  address=$(echo "${request}" | jq ".address")
  if [ "${address}" = "null" ]; then
    # address tag null but required
    trace "[wasabi_spend] address is required"
    return 1
  fi
  trace "[wasabi_spend] address=${address}"

  local instanceid
  instanceid=$(echo "${request}" | jq ".instanceId")
  trace "[wasabi_spend] instanceid=${instanceid}"

  local private
  private=$(echo "${request}" | jq ".private")
  trace "[wasabi_spend] private=${private}"

  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ "${spendingAmount}" != "null" ]; then
    minInstanceIndex=$instanceid
    maxInstanceIndex=$instanceid
  fi

  trace "[wasabi_spend] minInstanceIndex=${minInstanceIndex}"
  trace "[wasabi_spend] maxInstanceIndex=${maxInstanceIndex}"

  local balance
  local i
  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    # {"id":1,"private":true}
    balance=$(wasabi_get_balance "{\"instanceId\":$i,\"private\":${private}}")
    returncode=$?
    trace_rc ${returncode}

    if [ "${returncode}" -eq "0" ]; then
      trace "[wasabi_spend] balance=${balance}"
      balance=$(echo "${balance}" | jq ".balance")
      trace "[wasabi_spend] balance=${balance}"
      if [ "${balance}" -ge "${spendingAmount}" ]; then
        instanceid=$i
        trace "[wasabi_spend] spendingAmount=${spendingAmount}"
        break
      fi
    fi
  done

  trace "[wasabi_spend] Using instance ${instanceid}"

  local utxostring
  if [ "${balance}" -ge "${spendingAmount}" ]; then
    if [ "${private}" = "true" ]; then
      trace "[wasabi_spend] Spending only private coins"
      utxostring=$(build_utxo_to_spend ${spendingAmount} ${WASABI_MIXUNTIL} ${instanceid})
    else
      trace "[wasabi_spend] Spending private and non-private coins"
      utxostring=$(build_utxo_to_spend ${spendingAmount} 0 ${instanceid})
    fi
    # Amount is prefixed to utxostring, let's remove it
    utxostring="[$(echo "${utxostring}" | cut -d '[' -f2)"

    # curl -s -d '{"jsonrpc":"2.0","id":"1","method":"send", "params": { "sendto": "tb1qjlls57n6kgrc6du7yx4da9utdsdaewjg339ang", "coins":[{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0}], "amount": 15000, "label": "test transaction", "feeTarget":2 }}' http://wasabi_0:18099/
    response=$(send_to_wasabi ${instanceid} send "{\"payments\":[{\"sendto\":\"${address}\",\"amount\":${spendingAmount},\"label\":\"tx\",\"subtractFee\":true}],\"coins\":${utxostring},\"feeTarget\":2,\"password\":\"\"}")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -ne "0" ]; then
      return ${returncode}
    fi
  else
    response="{\"event\":\"wasabi_spend\",\"result\":\"error\",\"message\":\"Not enough funds\"}"
  fi

  echo ${response}

  return ${returncode}
}

wasabi_gettransactions() {
  trace "Entering wasabi_gettransactions()..."

  # args:
  # - instanceId: integer, optional
  # return all transactions of either one wasabi instance
  # or all instances, depending on the instanceId parameter

  # curl -s --data-binary '{"jsonrpc":"2.0","id":"1","method":"gethistory"}' http:/127.0.0.1:18099
  # "jsonrpc": "2.0",
  # "result": [
  #   {
  #     "datetime": "2019-10-01T12:31:57+00:00",
  #     "height": 597871,
  #     "amount": -2110090,
  #     "label": "David",
  #     "tx": "680d8940145f53cf2a0c24b27ba0bb53fbd639011eba3d23c9d53123ddae5f32"
  #   },
  #   {
  #     "datetime": "2019-10-04T17:00:15+00:00",
  #     "height": 597872,
  #     "amount": -2120000,
  #     "label": "Pablo",
  #     "tx": "e5e4486ad2c9fc6f3c262c4c64fa5fbcc607aa301182d45848a6692c5a0d0fc0"
  #   },
  #   {
  #     "datetime": "2019-09-22T11:59:32+00:00",
  #     "height": 5965600,
  #     "amount": 44480000,
  #     "label": "Coinbase",
  #     "tx": "6a2e99298dbbd201230a99e62ea584d7f63f62ad1de7166f24eb2e24867f6faf"
  #   },

  local request=${1}
  trace "[wasabi_gettransactions] request=${request}"

  # Let's make it work even for a GET request (equivalent to a POST with empty json object body)
  local instanceid
  if [ "$(echo "${request}" | cut -d ' ' -f1)" = "GET" ]; then
    instanceid="null"
  else
    instanceid=$(echo "${request}" | jq ".instanceId")
  fi
  trace "[wasabi_gettransactions] instanceid=${instanceid}"

  local first=true
  local result
  local response
  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ "${instanceid}" != "null" ]; then
    minInstanceIndex=$instanceid
    maxInstanceIndex=$instanceid
  fi

  trace "[wasabi_gettransactions] minInstanceIndex=${minInstanceIndex}"
  trace "[wasabi_gettransactions] maxInstanceIndex=${maxInstanceIndex}"

  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    response=$(send_to_wasabi ${i} gethistory "[]")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -ne "0" ]; then
      return ${returncode}
    fi
    response=$(echo "${response}" | jq -Mc ".result")

    if $first; then
      result="${response}"
      first=false
    else
      result="${result},${response}"
    fi
  done

  result=$(echo "[$result]" | jq -Mc "add")

  echo "{\"instanceId\":${instanceid},\"transactions\":${result}}"

  return 0
}
wasabi_getunspentcoins() {
  trace "Entering wasabi_getunspentcoins()..."

  # args:
  # - instanceId: integer, optional
  # return all transactions of either one wasabi instance
  # or all instances, depending on the instanceId parameter

  # curl -s --data-binary '{"jsonrpc":"2.0","id":"1","method":"listunspentcoins"}' http:/127.0.0.1:18099
  local request=${1}
  trace "[wasabi_getunspentcoins] request=${request}"

  # Let's make it work even for a GET request (equivalent to a POST with empty json object body)
  local instanceid
  if [ "$(echo "${request}" | cut -d ' ' -f1)" = "GET" ]; then
    instanceid="null"
  else
    instanceid=$(echo "${request}" | jq ".instanceId")
  fi
  trace "[wasabi_getunspentcoins] instanceid=${instanceid}"

  local first=true
  local result
  local response
  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ "${instanceid}" != "null" ]; then
    minInstanceIndex=$instanceid
    maxInstanceIndex=$instanceid
  fi

  trace "[wasabi_getunspentcoins] minInstanceIndex=${minInstanceIndex}"
  trace "[wasabi_getunspentcoins] maxInstanceIndex=${maxInstanceIndex}"

  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    response=$(send_to_wasabi ${i} listunspentcoins "[]")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -ne "0" ]; then
      return ${returncode}
    fi
    response=$(echo "${response}" | jq -Mc ".result")

    if $first; then
      result="${response}"
      first=false
    else
      result="${result},${response}"
    fi
  done

  result=$(echo "[$result]" | jq -Mc "add")

  echo "{\"instanceId\":${instanceid},\"unspentcoins\":${result}}"

  return 0
}
