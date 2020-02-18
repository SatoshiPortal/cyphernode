#!/bin/sh

. ./trace.sh

send_to_elements_watcher_node() {
  trace "Entering send_to_elements_watcher_node()..."
  local node_payload
  node_payload="$(send_to_elements_node ${WATCHING_ELEMENTS_NODE_RPC_URL}/${WATCHING_ELEMENTS_NODE_DEFAULT_WALLET} ${WATCHING_ELEMENTS_NODE_RPC_CFG} $@)"
  local returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne 0 ]; then
    # Ok, since we now have multiple watching wallets, we need to try them all if it fails
    # We have 2 right now: watching and watching-for-xpubs
    node_payload="$(send_to_elements_watcher_node_wallet ${WATCHER_BTC_NODE_XPUB_WALLET} $@)"
    returncode=$?
    trace_rc ${returncode}
  fi
  echo "$node_payload"
  return ${returncode}
}

send_to_xpub_elements_watcher_wallet() {
  trace "Entering send_to_xpub_elements_watcher_wallet()..."

  send_to_elements_node ${WATCHING_ELEMENTS_NODE_RPC_URL}/${WATCHING_ELEMENTS_NODE_XPUB_WALLET} ${WATCHING_ELEMENTS_NODE_RPC_CFG} $@
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_to_elements_watcher_node_wallet() {
  trace "Entering send_to_elements_watcher_node_wallet()..."
  local walletname=$1
  shift
  trace "[send_to_elements_watcher_node_wallet] walletname=${walletname}"
  send_to_elements_node ${WATCHING_ELEMENTS_NODE_RPC_URL}/${walletname} ${WATCHING_ELEMENTS_NODE_RPC_CFG} $@
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_to_elements_spender_node()
{
  trace "Entering send_to_elements_spender_node()..."
  send_to_elements_node ${SPENDING_ELEMENTS_NODE_RPC_URL}/${SPENDING_ELEMENTS_NODE_DEFAULT_WALLET} ${SPENDING_ELEMENTS_NODE_RPC_CFG} $@
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

  trace "[send_to_elements_node] curl -m 20 -s --config ${config} -H \"Content-Type: application/json\" -d \"${data}\" ${node_url}"
  result=$(curl -m 20 -s --config ${config} -H "Content-Type: application/json" -d "${data}" ${node_url})
  returncode=$?
  trace_rc ${returncode}
  trace "[send_to_elements_node] result=${result}"

  if [ "${returncode}" -eq 0 ]; then
    # Node responded, let's see if we got an error message from the node
    # jq -e will have a return code of 1 if the supplied tag is null.
    errorstring=$(echo "${result}" | jq -e ".error")
    if [ "$?" -eq "0" ]; then
      # Error tag not null, so there's an error
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

case "${0}" in *sendtoelementsnode.sh) send_to_elements_node $@;; esac
