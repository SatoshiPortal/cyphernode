#@IgnoreInspection BashAddShebang

# createpsbt: https://bitcoincore.org/en/doc/0.17.0/rpc/rawtransactions/createpsbt/
# walletcreatefundedpsbt https://bitcoincore.org/en/doc/0.17.0/rpc/wallet/walletcreatefundedpsbt/
# finalizepsbt https://bitcoincore.org/en/doc/0.17.0/rpc/rawtransactions/finalizepsbt/

. ./sendtobitcoinnode.sh
. ./walletoperations.sh
. ./walletutils.sh
. ./blockchainrpc.sh
. ./trace.sh
. ./watchrequest.sh

# quick win. TODO: integrate into wallet operations
# Refactor with multi wallet support

#vpub5Vyy1gQ7Hyk6ejVdsxkxaBDF29576mwTMYWKJY5hkwQ9MGE2nhfax4QY3VFvSRF3LwdvxbfakpqGWD1oty5FX8SvzgEvnt5W9xkeKuPZxiW

psbt_enable_request() {
  trace "Entering psbt_enable_request()..."
  local returncode
  local request=${1}
  local pub32=$(echo "${request}" | jq -er ".pub32")
  local label=$(echo "${request}" | jq -er ".label")
  local rescan=$(echo "${request}" | jq -er ".rescan")
  local rescan_block_start=$(echo "${request}" | jq -er ".rescanBlockStart")
  local rescan_block_end=$(echo "${request}" | jq -er ".rescanBlockEnd")

  if [ "${rescan}" != "true" ]; then
    rescan=false
  fi

  if [ "${rescan_block_start}" == "null" ]; then
    rescan_block_start=0
  fi

  if [ "${rescan_block_end}" == "null" ]; then
    rescan_block_end=0
  fi

  if [ "${label}" == "" ]; then
    label=psbt01
  fi

  trace "[psbt_enable_request] request=${request}"
  trace "[psbt_enable_request] pub32=${pub32}"
  trace "[psbt_enable_request] label=${label}"
  trace "[psbt_enable_request] rescan=${rescan}"
  trace "[psbt_enable_request] rescan_block_start=${rescan_block_start}"
  trace "[psbt_enable_request] rescan_block_end=${rescan_block_end}"


  local result
  result=$(psbt_enable ${pub32} "psbt01" "${rescan}" "${rescan_block_start}" "${rescan_block_end}")
  returncode=$?
  trace_rc ${returncode}
  echo ${result}
  return ${returncode}
}

psbt_disable_request() {
  trace "Entering psbt_disable_request()..."
  local returncode
  local result
  local label=$(echo "${request}" | jq -er ".label")
  if [ "${label}" == "" ]; then
    label=psbt01
  fi
  psbt_disable "${label}"
  returncode=$?
  trace_rc ${returncode}
  echo ${result}
  return ${returncode}
}




#     [
#       {                              (json object)
#         "txid": "hex",               (string, required) The transaction id
#         "vout": n,                   (numeric, required) The output number
#         "sequence": n,               (numeric, required) The sequence number
#       },
#       ...
#     ]
#     [
#       {                              (json object)
#         "address": amount,           (numeric or string, required) A key-value pair. The key (string) is the bitcoin address, the value (float or string) is the amount in BTC
#       },


psbt_begin_spend_request() {
  trace "Entering psbt_begin_spend_request()..."
}

psbt_end_spend_request() {
  trace "Entering psbt_end_spend_request()..."
}

psbt_listunspent() {
  trace "Entering psbt_listunspent()..."

}

psbt_begin_spend() {
  trace "Entering psbt_begin_spend()..."
}

psbt_end_spend() {
  trace "Entering psbt_end_spend()..."
  # <- upload psbt as file
  # walletprocesspsbt
  # finalizepsbt
  # sendrawtransaction
}

psbt_enable() {
  # if we have psbt enabled and there is no psbt01 wallet existing
  # we will need to call create_wallet to tell bitcoin core that we
  # need a wallet without private keys to which we will import
  # a watch only xpub using importmulti

  trace "Entering psbt_enable()..."


  local psbt_xpub=$1

  if [ "$psbt_xpub" == "" ]; then
    trace "[psbt_enable] no xpub to import."
    return 1;
  fi

  local wallet_name=${2:-psbt01}
  local rescan=${3}

  if [ "${rescan}" != true ]; then
    rescan=false
  fi

  local rescan_block_start=${4:-0}
  local rescan_block_end=${5:-0}

  trace "[psbt_enable] psbt_xpub=${psbt_xpub}"
  trace "[psbt_enable] wallet_name=${wallet_name}"
  trace "[psbt_enable] rescan=${rescan}"
  trace "[psbt_enable] rescan_block_start=${rescan_block_start}"
  trace "[psbt_enable] rescan_block_end=${rescan_block_end}"



  # will create a blank wallet with private keys disabled and import
  # receiving and change addresses
  trace "[psbt_enable] checking psbt wallet"
  local result
  result=$(create_wallet "${wallet_name}")
  returncode=$?
  if [ "$returncode" -eq 0 ]; then
    local errorcode=$(echo $result | jq -r '.error.code')
    trace "[psbt_enable] Error code=$errorcode"
    if [ "$errorcode" == "-4" ]; then
      trace '[psbt_enable] INFO: '
      trace $error | jq '.message'
    elif [ "$errorcode" == "null" ]; then
      local name=$( echo $result | jq -r '.result.name' )
      if [ "${name}" == "${wallet_name}" ]; then
        trace "[psbt_enable] Importing xpub ($psbt_xpub) into psbt wallet"
        # should be around the time HD wallets were introduced by Bitcoin core
        # testnet: block 154980 (1/1/2014)
        # mainnet: block 278000 (1/1/2014)
        if [ "${rescan_block_start}" -eq 0 ]; then
          if [ "${NETWORK}" == "mainnet" ]; then
            rescan_block_start=278000
          elif [ "${NETWORK}" == "testnet" ]; then
            rescan_block_start=154980
          fi
        fi

        if [ "${rescan_block_end}" -eq 0 ]; then
          rescan_block_end=$(get_blockcount)
        fi

        # if start is after end, dont rescan, cause blocks are being downloaded and
        # will see the information we want anyways
        if [ "${rescan}" == "true" ] && [ $rescan_block_end -lt $rescan_block_start ]; then
          rescan=false
        fi
        local result
        result=$(watchdescriptor ${wallet_name} ${psbt_xpub} 0 callback0conf callback1conf psbt01 watchdescriptor true ${rescan} ${rescan_block_start} ${rescan_block_end})
        returncode=$((returncode+$?))
      else
        trace "[psbt_enable] Unexpected result from createwallet."
        return 1;
      fi
    else
      trace "[psbt_enable] Unexpected error code from createwallet."
      return 1;
    fi
  else
    trace "[psbt_enable] Createwallet call failed. Exiting."
    return 1;
  fi

  echo $result

  if [ $returncode -gt 0 ]; then
    return 1
  fi

}

psbt_disable_label() {

  trace "Entering psbt_disable_label()..."
  local label=${1:-psbt01}

  trace "[psbt_disable_label] label=${label}"

  local returncode=0

  descriptors=$(sql "SELECT descriptor FROM watching_by_descriptor WHERE label=\"${label}\"" )
  resultcode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq 1 ]; then
    return 1
  fi

  trace "[psbt_disable_label] rows=${descriptors}"

  # delete all watches for psbt
  # for change and receiving
  local descriptor
  for descriptor in ${descriptors}; do
    delete_psbt_wallet_watches ${descriptor} deleteDescriptorWatch
    returncode=$(($returncode + $?))
  done

  if [[ "${returncode}" -gt 0 ]]; then
    return 1
  fi
}

psbt_disable() {

  trace "Entering psbt_disable()..."
  local label=${1:-psbt01}

  local returncode=0
  local is_scanning

  is_scanning=$(walletisscanning "psbt01" )
  trace "[psbt_disable] is_scanning=${is_scanning}"

  if [[ "${is_scanning}" == "true" ]]; then
    psbt_abort_rescanblockchain
    returncode=$(($returncode + $?))
  fi

  psbt_disable_label "psbt01"
  psbt_disable_label "psbt01_change"
  unload_psbt_wallet
  delete_psbt_wallet

  if [[ "${returncode}" -gt 0 ]]; then
    return 1
  fi
}

load_psbt_wallet() {
  trace "Entering load_psbt_wallet()..."
  local result
  result=$(load_wallet "psbt01")
  local returncode=$?
  trace_rc ${returncode}
  trace "[load_psbt_wallet] result=${result}"
  echo "${result}"
  return ${returncode}
}

unload_psbt_wallet() {
  trace "Entering unload_psbt_wallet()..."
  local result
  result=$(unload_wallet "psbt01")
  local returncode=$?
  trace_rc ${returncode}
  trace "[unload_psbt_wallet] result=${result}"
  echo "${result}"
  return ${returncode}
}

delete_psbt_wallet() {
  trace "Entering delete_psbt_wallet()..."
  local result
  result=$(delete_wallet "psbt01")
  local returncode=$?
  trace_rc ${returncode}
  trace "[delete_psbt_wallet] result=${result}"
  echo "${result}"
  return ${returncode}
}

delete_psbt_wallet_watches() {
  trace "Entering delete_psbt_wallet_watches()..."

  local descriptor=${1}
  local event_type=${2}

  trace "[delete_psbt_wallet_watches] descriptor=${descriptor}"
  trace "[delete_psbt_wallet_watches] eventtype=${event_type}"

  if [ "${descriptor}" == "" ]; then
    return 1;
  fi

  if [ "${event_type}" == "" ]; then
    return 1;
  fi

  local id
  local returncode
  trace "[delete_psbt_wallet_watches] Unwatch descriptor ${descriptor}"

  id=$(sql 'SELECT id FROM watching_by_descriptor WHERE descriptor="'${descriptor}'"')
  trace "[unwatchdescriptorrequest] id: ${id}"

  if [ "${id}" == "" ]; then
    return 1
  fi

  sql "DELETE FROM watching_by_descriptor WHERE id=${id}"
  returncode=$?
  trace_rc ${returncode}

  sql "DELETE FROM watching WHERE watching_by_descriptor_id=\"${id}\""
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"${event_type}\",\"descriptor\":\"${descriptor}\"}"
  trace "[unwatchdescriptorrequest] responding=${data}"

  echo ${data}
}
