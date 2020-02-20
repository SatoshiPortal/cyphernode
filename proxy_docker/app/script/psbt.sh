#@IgnoreInspection BashAddShebang

# createpsbt: https://bitcoincore.org/en/doc/0.17.0/rpc/rawtransactions/createpsbt/
# walletcreatefundedpsbt https://bitcoincore.org/en/doc/0.17.0/rpc/wallet/walletcreatefundedpsbt/
# finalizepsbt https://bitcoincore.org/en/doc/0.17.0/rpc/rawtransactions/finalizepsbt/

. ./sendtobitcoinnode.sh
. ./walletoperations.sh
. ./walletutils.sh
. ./blockchainrpc.sh
. ./trace.sh

# quick win. TODO: integrate into wallet operations
# Refactor with multi wallet support

#vpub5Vyy1gQ7Hyk6ejVdsxkxaBDF29576mwTMYWKJY5hkwQ9MGE2nhfax4QY3VFvSRF3LwdvxbfakpqGWD1oty5FX8SvzgEvnt5W9xkeKuPZxiW

psbt_enable_request() {
  trace "Entering psbt_enable_request()..."
  local returncode
  local request=${1}
  local pub32=$(echo "${request}" | jq -er ".pub32")
  local label=$(echo "${request}" | jq -er ".label")

  if [ "${label}" == "" ]; then
    label=psbt01
  fi

  trace "[psbt_enable_request] pub32=${pub32}"
  local result
  result=$(psbt_enable ${pub32})
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


psbt_import_address_range() {
  trace "Entering psbt_import_address_range()..."

}

psbt_begin_spend() {
  trace "Entering psbt_begin_spend()..."

  # walletcreatefundedpsbt
  #
}

psbt_end_spend() {
  trace "Entering psbt_end_spend()..."

  # finalizepsbt
  # sendrawtransaction
}

psbt_addtobatching() {

  trace "Entering psbt_addtobatching()..."
  local address=${1}
  trace "[psbt_addtobatching] address=${address}"
  local amount=${2}
  trace "[psbt_addtobatching] amount=${amount}"

  addtobatching $address $amount "psbt01"

  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

psbt_batchspend() {
  trace "Entering psbt_batchspend()..."
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

  local label=${2:-psbt01}

  # will create a blank wallet with private keys disabled and import
  # receiving and change addresses
  trace "[psbt_enable] checking psbt wallet"
  local result
  result=$(create_wallet "psbt01")
  returncode=$?
  if [ "$returncode" -eq 0 ]; then
    local errorcode=$(echo $result | jq -r '.error.code')
    trace "[psbt_enable] Error code=$errorcode"
    if [ "$errorcode" == "-4" ]; then
      trace '[psbt_enable] INFO: '
      trace $error | jq '.message'
    elif [ "$errorcode" == "null" ]; then
      local name=$( echo $result | jq -r '.result.name' )
      if [ "$name" == "psbt01" ]; then
        trace "[psbt_enable] Importing xpub ($psbt_xpub) into psbt wallet"
        local rescan_block_end
        rescan_block_end=$(get_blockcount)

        # should be around the time the first coldcard was sold
        # testnet: block 1063000 (12/30/2016)
        # mainnet: block 446000 (12/31/2016)
        local rescan_block_start=1063000
        local rescan=true

        # if start is after end, dont rescan, cause blocks are being downloaded and
        # will see the information we want anyways
        if [ $rescan_block_end -lt $rescan_block_start ]; then
          rescan=false
        fi
        local result
        result=$(watchdescriptor ${label} ${psbt_xpub} 0 callback0conf callback1conf psbt01 watchdescriptor true ${rescan} ${rescan_block_start} ${rescan_block_end})
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

  #return label here

}

psbt_disable_label() {

  trace "Entering psbt_disable_label()..."

  local returncode
  local label=${1}
  trace "[psbt_disable_label] label=${label}"

  if [ "$label" == "" ]; then
    return 1
  fi

  descriptors=$(sql "SELECT descriptor FROM watching_by_descriptor WHERE label=\"${label}\"" )
  returncode=$?
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
  done
}

psbt_disable() {

  local label=${1:-psbt01}
  local resultcode

  psbt_disable_label "${label}"
  resultcode=$?

  if [ ${resultcode} -eq 1 ]; then
    return 1
  fi

  psbt_disable_label "${label}_change"
  resultcode=$?

  if [ ${resultcode} -eq 1 ]; then
    return 1
  fi

  # if psbt wallet is loaded: unload psbt wallet
  unload_psbt_wallet
  # delete wallet file
  delete_psbt_wallet
}

load_psbt_wallet() {
  trace "Entering load_psbt_wallet()..."
  local result
  result=$(load_wallet "psbt01")
  local returncode=$?
  trace_rc ${returncode}
  trace "[load_psbt_wallet] result=${result}"
  return ${returncode}
}

unload_psbt_wallet() {
  trace "Entering unload_psbt_wallet()..."
  local result
  result=$(unload_wallet "psbt01")
  local returncode=$?
  trace_rc ${returncode}
  trace "[unload_psbt_wallet] result=${result}"
  return ${returncode}
}

delete_psbt_wallet() {
  trace "Entering delete_psbt_wallet()..."
  local result
  result=$(delete_wallet "psbt01")
  local returncode=$?
  trace_rc ${returncode}
  trace "[delete_psbt_wallet] result=${result}"
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
