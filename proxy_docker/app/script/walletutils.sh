#!/usr/bin/env bash
. ./trace.sh
. ./sendtobitcoinnode.sh


create_wallet_request() {
  trace "Entering create_wallet_request()..."

  local request=${1}
  local returncode
  local result
  local wallet_name=$(echo "${request}" | jq -r ".walletName")
  local disableprivatekeys=$(echo "${request}" | jq -r ".disablePrivateKeys")
  local blank=$(echo "${request}" | jq -r ".blank")

  if [ "${wallet_name}" == "" ]; then
    trace "[create_wallet_request] no wallet file"
    return 1
  fi

  if [ "${disableprivatekeys}" != "true" ]; then
    disableprivatekeys=false
  fi

  if [ "${blank}" != "true" ]; then
    blank=false
  fi

  result=$(create_wallet "${wallet_name}" "${disableprivatekeys}" "${blank}")
  returncode=$?

  echo "${result}"
  return ${returncode}
}

create_wallet() {
  # defaults to blank wallet to be used for importing
  # keys for watch only mode
  trace "[Entering create_wallet()]"

  local walletname=${1}
  local disableprivatekeys=${2:-true}
  local blank=${3:-true}

  if [ "$disableprivatekeys" != "false" ]; then
      disableprivatekeys="true"
  fi

  if [ "$blank" != "false" ]; then
      blank="true"
  fi

  local rpcstring="{\"method\":\"createwallet\",\"params\":[\"${walletname}\",${disableprivatekeys},${blank}]}"
  trace "[create_wallet] rpcstring=${rpcstring}"

  local result
  result=$(send_to_bitcoin_node ${WATCHER_NODE} ${WATCHER_NODE_RPC_CFG} ${rpcstring})
  local returncode=$?

  trace "[create_wallet] result=${result}"
  echo "${result}"

  return ${returncode}
}

load_wallet_request() {
  trace "Entering create_wallet_request()..."

  local request=${1}
  local returncode
  local result
  local wallet_name=$(echo "${request}" | jq -r ".walletName")

  if [ "${wallet_name}" == "" ]; then
    trace "[load_wallet_request] no wallet file"
    return 1
  fi

  result=$(load_wallet "${wallet_name}")
  returncode=$?

  echo "${result}"
  return ${returncode}
}

load_wallet() {
  trace "Entering load_wallet()..."

  local wallet_name=${1}

  if [ "${wallet_name}" == "" ]; then
    trace "[load_wallet] no wallet file"
    return 1
  fi

  local rpcstring="{\"method\":\"loadwallet\",\"params\":[\"${wallet_name}\"]}"
  local result
  result=$(send_to_bitcoin_node ${WATCHER_NODE} ${WATCHER_NODE_RPC_CFG} ${rpcstring})
  local returncode=$?
  trace_rc ${returncode}

  trace "[load_wallet] result=${result}"
  echo "${result}"
  return ${returncode}
}

unload_wallet_request() {
  trace "Entering unload_wallet_request()..."

  local request=${1}
  local returncode
  local result
  local wallet_name=$(echo "${request}" | jq -r ".walletName")

  if [ "${wallet_name}" == "" ]; then
    trace "[unload_wallet_request] no wallet file"
    return 1
  fi

  result=$(unload_wallet "${wallet_name}")
  returncode=$?

  echo "${result}"
  return ${returncode}
}

unload_wallet() {
  trace "Entering unload_wallet()..."

  local wallet_name=${1}

  if [ "${wallet_name}" == "" ]; then
    trace "[unload_wallet] no wallet file"
    return 1
  fi

  local rpcstring="{\"method\":\"unloadwallet\",\"params\":[\"${wallet_name}\"]}"
  local result
  result=$(send_to_bitcoin_node ${WATCHER_NODE} ${WATCHER_NODE_RPC_CFG} ${rpcstring})
  local returncode=$?
  trace_rc ${returncode}
  trace "[unload_wallet] result=${result}"
  echo "${result}"
  return ${returncode}
}

delete_wallet_request() {
  trace "Entering delete_wallet_request()..."

  local request=${1}
  local returncode
  local result
  local wallet_name=$(echo "${request}" | jq -r ".walletName")
  local create_backup=$(echo "${request}" | jq -r ".createBackup")

  if [ "${wallet_name}" == "" ]; then
    trace "[delete_wallet_request] no wallet file"
    return 1
  fi

  if [ "${create_backup}" != "false" ]; then
      create_backup="true"
  fi

  result=$(delete_wallet "${wallet_name}" "${create_backup}")
  returncode=$?

  echo "${result}"
  return ${returncode}
}

delete_wallet() {

  # VERRRRRY DANGEROUS!!!
  # Do not pass "false" as second argument unless you really
  # want to delete a wallet without creating a backup first
  # REALLY!! I'M SERIOUS!

  trace "Entering delete_wallet()..."

  local wallet_name=${1}
  local create_backup=${2:-true}

  trace "[delete_wallet] wallet_name=${wallet_name}"
  trace "[delete_wallet] create_backup=${create_backup}"

  #always create backup of wallet, unless turned off
  if [[ ${create_backup} != "false" ]]; then
    create_backup="true"
  fi

  if [[ "${wallet_name}" == "" ]]; then
    trace "[delete_wallet] no wallet file"
    return 1
  fi

  local network_folder="testnet3"

  if [[ "${NETWORK}" == "mainnet" ]]; then
    network_folder="mainnet"
  elif [[ "${NETWORK}" == "regtest" ]]; then
    network_folder="regtest"
  fi

  local wallet_dir="/.bitcoin/${network_folder}"
  local to_check="${wallet_name} wallets/${wallet_name}"

  trace "[delete_wallet] wallet_dir=${wallet_dir}"
  trace "[delete_wallet] to_check=${to_check}"

  if [[ "${create_backup}" == "true" ]]; then
    backup_wallet "${wallet_name}"
  fi

  for wallet_folder in ${to_check}; do
    trace "[delete_wallet] checking: ${wallet_folder}"
    if [[ -e "${wallet_dir}/${wallet_folder}" ]]; then
      trace "[delete_wallet] deleting: ${wallet_dir}/${wallet_folder}"
      # DANGEROUS!!!!
      rm -rf "${wallet_dir}/${wallet_folder}"
    fi
  done

}

backup_wallet_request() {
  trace "Entering backup_wallet_request()..."

  local request=${1}
  local returncode
  local result
  local wallet_name=$(echo "${request}" | jq -r ".walletName")

  if [ "${wallet_name}" == "" ]; then
    trace "[backup_wallet_request] no wallet file"
    return 1
  fi

  result=$(backup_wallet "${wallet_name}")
  returncode=$?

  echo "${result}"
  return ${returncode}
}

backup_wallet() {
  trace "Entering backup_wallet()..."

  local wallet_name=${1}

  if [ "${wallet_name}" == "" ]; then
    trace "[backup_wallet] no wallet"
    return 1
  fi

  local network_folder="testnet3"

  if [ "${NETWORK}" == "mainnet" ]; then
    network_folder="mainnet"
  elif [ "${NETWORK}" == "regtest" ]; then
    network_folder="regtest"
  fi

  local backup_date=$(date +"%y-%m-%d-%T")
  local wallet_dir="/.bitcoin/${network_folder}"
  local backup_dir="/.bitcoin/.wallet_backups/${network_folder}"
  local to_check="${wallet_name} wallets/${wallet_name}"

  trace "[backup_wallet] wallet_name=${wallet_name}"
  trace "[backup_wallet] network_folder=${network_folder}"
  trace "[backup_wallet] backup_date=${backup_date}"
  trace "[backup_wallet] wallet_dir=${wallet_dir}"
  trace "[backup_wallet] to_check=${to_check}"

  for wallet_folder in ${to_check}; do
    trace "[backup_wallet] checking: ${wallet_dir}/${wallet_folder}"
    if [ -e "${wallet_dir}/${wallet_folder}" ]; then
      local target_backup_folder=$(dirname "${backup_dir}/${wallet_folder}-${backup_date}")
      trace "[backup_wallet] target_backup_folder=${target_backup_folder}"
      if [ ! -d "${target_backup_folder}" ]; then
        trace "[backup_wallet] creating: ${target_backup_folder}"
        mkdir -p "${target_backup_folder}"
      fi
      trace "[backup_wallet] creating backup: ${wallet_dir}/${wallet_folder} -> ${backup_dir}/${wallet_folder}-${backup_date}"
      cp -r "${wallet_dir}/${wallet_folder}" "${backup_dir}/${wallet_folder}-${backup_date}"
    fi
  done
}

fingerprint_from_pub32() {
  local pub32=$1
  echo -n "$pub32" | md5 | cut -c1-8
  return $?
}
