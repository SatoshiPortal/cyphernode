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

# smallest_balance_wasabi_index
# returns instance where balance is the smallest between 0 and WASABI_INSTANCE_COUNT
smallest_balance_wasabi_index() {
  trace "Entering smallest_balance_wasabi_index()..."

  balances=$(wasabi_getbalances)
  trace "[smallest_balance_wasabi_index] balances=${balances}"

  instanceid=$(echo "$balances" | jq -r "to_entries | min_by(.value.total) | .key")
  trace "[smallest_balance_wasabi_index] Using instance ${instanceid}"

  echo ${instanceid}
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
    instanceid=$(smallest_balance_wasabi_index)
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
  local rcvd_0conf=0
  local mixing=0
  local priv_bal=0
  local total=0
  local priv_total=0
  local rcvd_0conf_total=0
  local mixing_total=0
  local balances
  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))
  local minanonset="${1-$WASABI_MIXUNTIL}"

  trace "[wasabi_getbalances] WASABI_MIXUNTIL=${minanonset}"

  for i in `seq ${minInstanceIndex} ${maxInstanceIndex}`
  do
    # wasabi rpc: listunspentcoins
    response=$(send_to_wasabi ${i} listunspentcoins "[]")
    returncode=$?
    trace_rc ${returncode}

    echo "${response}" | jq -e ".error" > /dev/null
    returncode=$((${returncode} + $?))
    trace_rc ${returncode}

    # "jq -e" returns 1 when error tag is null!
    if [ "${returncode}" -ne "1" ]; then
      # If this instance fails, skip it and ignore it
      trace "[wasabi_getbalances] Instance $i is down or in error, skipping..."
      continue
    fi

    # When calling wasabi_getnewaddress, there's always a label ("unknown" when not specified) so we assume when a UTXO has
    # a label, has an anonset of 1 and is unconfirmed, it is an unconfirmed deposit waiting to be confirmed to be part of a mix.
    rcvd_0conf=$(echo "${response}" | jq ".result | map(select(.anonymitySet == 1 and .confirmed == false and .label != \"\") | .amount) | add")
    if [ "${rcvd_0conf}" = "null" ]; then
      rcvd_0conf=0
    fi
    trace "[wasabi_getbalances] rcvd_0conf ${i}=${rcvd_0conf}"

    rcvd_0conf_total=$((${rcvd_0conf_total}+${rcvd_0conf}))
    trace "[wasabi_getbalances] rcvd_0conf_total=${rcvd_0conf_total}"

    # When calling wasabi_getnewaddress, there's always a label ("unknown" when not specified) so we assume when a UTXO has
    # no label with an anonset less than MIXUNTIL, or is confirmed with an anonset of 1, it is ready to be part of a mix.
    mixing=$(echo "${response}" | jq ".result | map(select(.anonymitySet == 1 and .confirmed == true or .label == \"\" and .anonymitySet < ${minanonset}) | .amount) | add")
    if [ "${mixing}" = "null" ]; then
      mixing=0
    fi
    trace "[wasabi_getbalances] mixing ${i}=${mixing}"

    mixing_total=$((${mixing_total}+${mixing}))
    trace "[wasabi_getbalances] mixing_total=${mixing_total}"

    # As soon as a UTXO has an anonset of MIXUNTIL, it is considered private.
    priv_bal=$(echo "${response}" | jq ".result | map(select(.anonymitySet >= ${minanonset}) | .amount) | add")
    if [ "${priv_bal}" = "null" ]; then
      priv_bal=0
    fi
    trace "[wasabi_getbalances] priv_bal ${i}=${priv_bal}"

    priv_total=$((${priv_total}+${priv_bal}))
    trace "[wasabi_getbalances] priv_total=${priv_total}"

    balance=$(echo "${response}" | jq ".result | map(.amount) | add")
    if [ "${balance}" = "null" ]; then
      balance=0
    fi
    trace "[wasabi_getbalances] balance ${i}=${balance}"

    total=$((${total}+${balance}))
    trace "[wasabi_getbalances] total=${total}"

    if [ -z "${balances}" ]; then
      balances="\"${i}\":{\"rcvd0conf\":${rcvd_0conf},\"mixing\":${mixing},\"private\":${priv_bal},\"total\":${balance}}"
    else
      balances="${balances},\"${i}\":{\"rcvd0conf\":${rcvd_0conf},\"mixing\":${mixing},\"private\":${priv_bal},\"total\":${balance}}"
    fi
    trace "[wasabi_getbalances] balances=${balances}"
  done

  if [ -z "${balances}" ]; then
    balances="{\"all\":{\"rcvd0conf\":${rcvd_0conf_total},\"mixing\":${mixing_total},\"private\":${priv_total},\"total\":${total}}}"
  else
    balances="{${balances},\"all\":{\"rcvd0conf\":${rcvd_0conf_total},\"mixing\":${mixing_total},\"private\":${priv_total},\"total\":${total}}}"
  fi
  trace "[wasabi_getbalances] balances=${balances}"
  echo "${balances}"

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
  local toaddress
  local utxo_to_spend
  local balance
  local matching_wallet 
  local address_index=1
  local minanonset
  # Check auto spend setting from cyphernode_props table
  # '_disabled' -> disable autospend
  # '_spender' -> send mixed coins to spending wallet
  # '*' -> if value is a label for one of our watching wallets, send to that --> Mix and auto send to your Trezor/Ledger :)
  local wasabi_autospend_cfg=$(sql "SELECT value FROM cyphernode_props WHERE property LIKE 'wasabi_batchprivatetospender_cfg'")
  trace "[wasabi_batchprivatetospender] spend to wallet setting: ${wasabi_autospend_cfg}"
  # Maitain backward compatiblty by falling back on default behavoir if the config is not set in props table
  if [ -n "${wasabi_autospend_cfg}" ]; then
     # if cfg exists in prop and set to "_disbaled" wasabi autospending setting means it's disabled
     if [ "${wasabi_autospend_cfg}" = "_disabled" ]; then
        trace "[wasabi_batchprivatetospender] batch private send is disabled: ${wasabi_autospend_cfg}"
        return
     else 
        # Otherwise it's '_spender' to send it to the spending wallet or a label for one of our watching wallets
        [ "${wasabi_autospend_cfg}" = "_spender" ] && matching_wallet="_spender" || matching_wallet=$(getactivexpubwatches | jq --arg target "${wasabi_autospend_cfg}"  '.watches | .[] | select(.label==$target) | .label')
        if [ -z "${matching_wallet}" ] || [ "${matching_wallet}" = "null" ]; then
            trace "[wasabi_batchprivatetospender] could not determine spending target wallet from settings, aborting"
            return;
        fi
     fi
  else
     trace "[wasabi_batchprivatetospender] autospend cfg not detected, falling back to defaults"
     matching_wallet="_spender"
  fi

  # allow for a dynamic mixuntil config too :)
  local wasabi_autospend_minanonset=$(sql "SELECT value FROM cyphernode_props WHERE property LIKE 'wasabi_batchprivatetospender_minanonset'")
  [ -n "${wasabi_autospend_minanonset}" ] && minanonset="${wasabi_autospend_minanonset}" || minanonset="${WASABI_MIXUNTIL}"

  trace "[wasabi_batchprivatetospender] spending to wallet ${matching_wallet} using minanonset ${minanonset}"

  for instanceid in `seq 0 $((WASABI_INSTANCE_COUNT-1))`
  do
    # Get list of UTXO with anonymityset > configured threshold
    # build_utxo_to_spend <spendingAmount> <anonset> <instanceid>
    utxo_to_spend=$(build_utxo_to_spend 0 ${minanonset} ${instanceid})
    # Amount is prefixed to utxostring, let's consider it
    amount=$(echo "${utxo_to_spend}" | cut -d '[' -f1)
    trace "[wasabi_batchprivatetospender] amount=${amount}"

    if [ "${amount}" -gt "0" ]; then
      trace "[wasabi_batchprivatetospender] We have mixed coins ready to consume!"
      # Get an address from the correct wallet
      case "$wasabi_autospend_cfg" in
	      "_spender") toaddress="$(getnewaddress | jq '.address')" ;;
	      *) toaddress=$(get_unused_addresses_by_watchlabel "${wasabi_autospend_cfg}" | jq --arg index "$((address_index++))" '.label_unused_addresses | .[($index| tonumber)].address') ;;
      esac
      trace "[wasabi_batchprivatetospender] toaddress=${toaddress} address_index=${address_index}"

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

  # We only want mixed coins with correct minimum anonymitySet.
  utxos=$(echo "${response}" | jq -Mac ".result[] | select(.anonymitySet >= ${anonset}) | {\"transactionid\": .txid,index,amount}")
  trace "[build_utxo_to_spend] utxos=${utxos}"

  # We'll use this amount list to increase up to the amount to spend in the following loop.
  amounts=$(echo "${utxos}" | jq -Mac '.amount')

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
# requesthandler_request_string: JSON object with "id", "private", "amount" and "address" properties: {"id":1,"private":true,"amount":0.00103440,"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp", minanonset: 20 }
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
  # - minanonset: number, optional, default=WASABI_MIXUNTIL

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
  address=$(echo "${request}" | jq -r ".address")
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

  local label
  label=$(echo "${request}" | jq -r ".label")
  # check if label provided
  if [[ -z "${label}"  ]] || [[ "${label}" = "null" ]]; then
    label="tx"
  fi
  trace "[wasabi_spend] label=${label}"

  local minanonset
  minanonset=$(echo "${request}" | jq ".minanonset")
  # check minnonset provided and is valid number > 1 , otherwise fallback to config
  if [[ -z "${minanonset}"  ]] || [[ "${minanonset}" -lt 1 ]]; then
    minanonset=$WASABI_MIXUNTIL	
  fi
  trace "[wasabi_spend] minanonset=${minanonset}"

  local minInstanceIndex=0
  local maxInstanceIndex=$((WASABI_INSTANCE_COUNT-1))

  if [ "${instanceid}" != "null" ]; then
    minInstanceIndex=$instanceid
    maxInstanceIndex=$instanceid
  fi

  trace "[wasabi_spend] minInstanceIndex=${minInstanceIndex}"
  trace "[wasabi_spend] maxInstanceIndex=${maxInstanceIndex}"

  balances=$(wasabi_getbalances "${minanonset}")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne "0" ]; then
     return "${returncode}"
  fi
  trace "[wasabi_spend] balances=${balances}"
  # .value.total or .value.private is needed ?
  local balance_type
  case "$private" in
	   "true") balance_type="private" ;;
	   *) balance_type="total" ;;
  esac
  trace "[wasabi_spend] spendingAmount=${spendingAmount} from balance type ${balance_type}"
  # search balances for first entry with balance type (total, or private) >= spending amount that's withing instance bounds
  instanceid=$(echo "$balances" | jq -r --arg btype "${balance_type}" --arg amount "${spendingAmount}" --arg min "${minInstanceIndex}" --arg max "${maxInstanceIndex}"  '
  [
    to_entries | .[] | select(
       .value[$btype] >= ($amount | tonumber) and .key >= ($min | tostring)  and .key <= ($max | tostring)
    )
  ] | .[0].key')
  trace "[wasabi_spend] Using instance ${instanceid}"

  local utxostring
  if [ ! -z "${instanceid}" ] && [ "${instanceid}" != "null" ]; then
    if [ "${private}" = "true" ]; then
      trace "[wasabi_spend] Spending only private coins"
      utxostring=$(build_utxo_to_spend ${spendingAmount} ${minanonset} ${instanceid})
    else
      trace "[wasabi_spend] Spending private and non-private coins"
      utxostring=$(build_utxo_to_spend ${spendingAmount} 0 ${instanceid})
    fi
    # Amount is prefixed to utxostring, let's remove it
    utxostring="[$(echo "${utxostring}" | cut -d '[' -f2)"

    # curl -s -d '{"jsonrpc":"2.0","id":"1","method":"send", "params": { "sendto": "tb1qjlls57n6kgrc6du7yx4da9utdsdaewjg339ang", "coins":[{"transactionid":"8c5ef6e0f10c68dacd548bbbcd9115b322891e27f741eb42c83ed982861ee121", "index":0}], "amount": 15000, "label": "test transaction", "feeTarget":2 }}' http://wasabi_0:18099/
    response=$(send_to_wasabi ${instanceid} send "{\"payments\":[{\"sendto\":\"${address}\",\"amount\":${spendingAmount},\"label\":\"${label}\",\"subtractFee\":true}],\"coins\":${utxostring},\"feeTarget\":2,\"password\":\"\"}")
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
