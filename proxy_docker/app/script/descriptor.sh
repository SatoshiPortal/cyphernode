. ./trace.sh
. ./sendtobitcoinnode.sh

getdescriptorinfo_rpc() {
  trace "[Entering getdescriptorinfo_rpc()]"

  local descriptor=${1}

  local rpcstring="{\"method\":\"getdescriptorinfo\",\"params\":[\"${descriptor}\"]}"
  trace "[getdescriptorinfo_rpc] rpcstring=${rpcstring}"

  local result
  result=$(send_to_psbt_wallet ${rpcstring})
  local returncode=$?

  echo "${result}"
  return ${returncode}
}

derive_from_descriptor() {
  trace "[Entering getdescriptorinfo_rpc()]"

  local descriptor=${1}
  local nStart=${2}
  local nEnd=${3}

  local rpcstring="{\"method\":\"deriveaddresses\",\"params\":[\"${descriptor}\",[${nStart},${nEnd}]]}"
  trace "[getdescriptorinfo_rpc] rpcstring=${rpcstring}"

  local result
  result=$(send_to_psbt_wallet ${rpcstring})
  local returncode=$?

  if [ $returncode -eq 0 ]; then
    addresses=$(echo "${result}" | jq '.result')
    if [ "$addresses" == "null" ]; then
      return 1
    fi
    echo "${addresses}" | jq '.[]'
  fi

  return ${returncode}
}
