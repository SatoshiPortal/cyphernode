#!/bin/sh

. ./trace.sh

send_to_elements_watcher_node() {
  trace "Entering send_to_elements_watcher_node()..."
  local node_payload
  node_payload="$(send_to_elements_node "${WATCHER_ELEMENTS_NODE_RPC_URL}/${WATCHER_ELEMENTS_NODE_DEFAULT_WALLET}" "${WATCHER_ELEMENTS_NODE_RPC_CFG}" "$@")"
  local returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne 0 ]; then
    # Ok, since we now have multiple watching wallets, we need to try them all if it fails
    # We have 2 right now: watching and watching-for-xpubs
    node_payload="$(send_to_elements_watcher_node_wallet "${WATCHER_ELEMENTS_NODE_XPUB_WALLET}" "$@")"
    returncode=$?
    trace_rc ${returncode}
  fi
  echo "$node_payload"
  return ${returncode}
}

send_to_xpub_elements_watcher_wallet() {
  trace "Entering send_to_xpub_elements_watcher_wallet()..."

  send_to_elements_node "${WATCHER_ELEMENTS_NODE_RPC_URL}/${WATCHER_ELEMENTS_NODE_XPUB_WALLET}" "${WATCHER_ELEMENTS_NODE_RPC_CFG}" "$@"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_to_elements_watcher_node_wallet() {
  trace "Entering send_to_elements_watcher_node_wallet()..."
  local walletname=$1
  shift
  trace "[send_to_elements_watcher_node_wallet] walletname=${walletname}"
  send_to_elements_node "${WATCHER_ELEMENTS_NODE_RPC_URL}/${walletname}" "${WATCHER_ELEMENTS_NODE_RPC_CFG}" "$@"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_to_elements_spender_node()
{
  trace "Entering send_to_elements_spender_node()..."

  local walletname=${SPENDER_ELEMENTS_NODE_DEFAULT_WALLET}
  if [ -n "$2" ]; then
    if ! validate_elements_spender_wallet "$2"; then
      echo '{"result":null,"error":{"code":-8,"message":"wallet must be one of 01, 02, 03, or 04"}}'
      return 1
    fi
    walletname="spending${2}.dat"
  fi
  trace "[send_to_elements_spender_node] wallet: ${walletname}"

  send_to_elements_node "${SPENDER_ELEMENTS_NODE_RPC_URL}/${walletname}" "${SPENDER_ELEMENTS_NODE_RPC_CFG}" "$1"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_to_elements_node()
{
  trace "Entering send_to_elements_node()..."
  local returncode
  local result
  local errorstring
  local node_url=${1}
  local config=${2}
  local data=${3}

  trace "[send_to_elements_node] curl -m 60 -s --config ${config} -H \"Content-Type: application/json\" --data \"${data}\" --url \"${node_url}\""
  result=$(curl -m 60 -s --config "${config}" -H "Content-Type: application/json" --data "${data}" --url "${node_url}")
  returncode=$?
  trace_rc ${returncode}
  # trace "[send_to_elements_node] result=${result}"

  if [ "${returncode}" -eq 0 ]; then
    if ! echo "${result}" | jq -e 'type == "object" and has("result") and has("error")' >/dev/null 2>&1; then
      trace "[send_to_elements_node] Node returned an invalid JSON-RPC response"
      returncode=1
    elif ! echo "${result}" | jq -e '.error == null' >/dev/null 2>&1; then
      errorstring=$(echo "${result}" | jq -c '.error')
      trace "[send_to_elements_node] Node responded, error found in response: ${errorstring}"
      returncode=1
    else
      trace "[send_to_elements_node] Node responded, no error found in response, yayy!"
    fi
  fi

  # Output response to stdout before exiting with return code
  echo "${result}"

  trace_rc ${returncode}
  return ${returncode}
}

send_batch_to_elements_spender_node() {
  trace "Entering send_batch_to_elements_spender_node()..."

  local walletname=${SPENDER_ELEMENTS_NODE_DEFAULT_WALLET}
  if [ -n "$2" ]; then
    if ! validate_elements_spender_wallet "$2"; then
      echo '{"result":null,"error":{"code":-8,"message":"wallet must be one of 01, 02, 03, or 04"}}'
      return 1
    fi
    walletname="spending${2}.dat"
  fi
  trace "[send_batch_to_elements_spender_node] wallet: ${walletname}"

  send_batch_to_elements_node "${SPENDER_ELEMENTS_NODE_RPC_URL}/${walletname}" "${SPENDER_ELEMENTS_NODE_RPC_CFG}" "$1"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_batch_to_elements_node() {
  trace "Entering send_batch_to_elements_node()..."
  local returncode
  local result
  local errorstring
  local node_url=${1}
  local config=${2}
  local body_file=${3}

  trace "[send_batch_to_elements_node] curl -m 20 -s --config ${config} -H \"Content-Type: application/json\" --data-binary @${body_file} --url \"${node_url}\""
  result=$(curl -m 20 -s --config "${config}" -H "Content-Type: application/json" --data-binary "@${body_file}" --url "${node_url}")
  returncode=$?
  trace_rc ${returncode}
  trace "[send_batch_to_elements_node] result=${result}"

  # Since there's an independant response for each batch item, we won't check for errors here.

  # Output response to stdout before exiting with return code
  echo "${result}"

  trace_rc ${returncode}
  return ${returncode}
}

validate_elements_spender_wallet() {
  case "${1}" in
    01|02|03|04) return 0 ;;
    *) return 1 ;;
  esac
}

case "${0}" in *sendtoelementsnode.sh) send_to_elements_node "$@";; esac
