#!/bin/sh

. ./trace.sh

send_to_watcher_node() {
  trace "Entering send_to_watcher_node()..."
  local node_payload
  node_payload="$(send_to_bitcoin_node "${WATCHER_BTC_NODE_RPC_URL}/${WATCHER_BTC_NODE_DEFAULT_WALLET}" "${WATCHER_BTC_NODE_RPC_CFG}" "$@")"
  local returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne 0 ]; then
    # Ok, since we now have multiple watching wallets, we need to try them all if it fails
    # We have 2 right now: watching and watching-for-xpubs
    node_payload="$(send_to_watcher_node_wallet "${WATCHER_BTC_NODE_XPUB_WALLET}" "$@")"
    returncode=$?
    trace_rc ${returncode}
  fi
  echo "$node_payload"
  return ${returncode}
}

send_to_xpub_watcher_wallet() {
  trace "Entering send_to_xpub_watcher_wallet()..."

  send_to_bitcoin_node "${WATCHER_BTC_NODE_RPC_URL}/${WATCHER_BTC_NODE_XPUB_WALLET}" "${WATCHER_BTC_NODE_RPC_CFG}" "$@"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_to_watcher_node_wallet() {
  trace "Entering send_to_watcher_node_wallet()..."
  local walletname=$1
  shift
  trace "[send_to_watcher_node_wallet] walletname=${walletname}"
  send_to_bitcoin_node "${WATCHER_BTC_NODE_RPC_URL}/${walletname}" "${WATCHER_BTC_NODE_RPC_CFG}" "$@"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_to_spender_node() {
  trace "Entering send_to_spender_node()..."

  local walletname=${SPENDER_BTC_NODE_DEFAULT_WALLET}
  if [ -n "$2" ]; then
    walletname="spending${2}.dat"
  fi
  trace "[send_to_spender_node]wallet: ${walletname}"

  send_to_bitcoin_node "${SPENDER_BTC_NODE_RPC_URL}/${walletname}" "${SPENDER_BTC_NODE_RPC_CFG}" "$1"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

# Read balances from one exact, operator-configured wallet name. This is kept
# separate from send_to_spender_node(), whose optional argument is a legacy
# numeric selector used by all spender operations.
send_getbalances_to_spender_wallet_name() {
  trace "Entering send_getbalances_to_spender_wallet_name()..."

  local walletname=${1:-}
  local encoded_walletname
  local returncode

  if [ -z "${walletname}" ]; then
    trace "[send_getbalances_to_spender_wallet_name] Missing wallet name"
    return 1
  fi

  encoded_walletname=$(printf '%s' "${walletname}" | jq -sRr '@uri')
  returncode=$?
  trace_rc ${returncode}
  # curl normalizes literal dot path segments, which would rewrite the
  # /wallet/<name> RPC target; encode dot-only names so they survive.
  case "${walletname}" in
    .) encoded_walletname='%2E' ;;
    ..) encoded_walletname='%2E%2E' ;;
  esac
  if [ "${returncode}" -ne 0 ] || [ -z "${encoded_walletname}" ]; then
    trace "[send_getbalances_to_spender_wallet_name] Could not encode wallet name"
    return 1
  fi

  trace "[send_getbalances_to_spender_wallet_name] wallet: ${walletname}"
  send_to_bitcoin_node \
    "${SPENDER_BTC_NODE_RPC_URL}/${encoded_walletname}" \
    "${SPENDER_BTC_NODE_RPC_CFG}" \
    '{"method":"getbalances"}'
  returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

# Execute an explicitly scoped RPC against an operator-named wallet. Prepared
# flows never use the legacy numeric selector because every wallet role must
# remain independently auditable.
# Unlike the legacy sender this path deliberately omits curl --fail: bitcoind
# returns JSON-RPC errors with non-2xx statuses, and --fail would discard the
# body, collapsing every distinct failure (insufficient funds, wallet not
# loaded, unknown method) into one opaque upstream error.
send_to_spender_wallet_name() {
  trace "Entering send_to_spender_wallet_name()..."
  local walletname=${1:-}
  local data=${2:-}
  local encoded_walletname returncode result
  [ -n "${walletname}" ] && [ -n "${data}" ] || return 1
  encoded_walletname=$(printf '%s' "${walletname}" | jq -sRr '@uri') || return 1
  [ -n "${encoded_walletname}" ] || return 1
  result=$(curl -m 20 --show-error --silent --path-as-is --config "${SPENDER_BTC_NODE_RPC_CFG}" -H "Content-Type: application/json" -d "${data}" "${SPENDER_BTC_NODE_RPC_URL}/${encoded_walletname}")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    if ! printf '%s' "${result}" | jq -e 'type == "object" and has("result") and has("error")' >/dev/null 2>&1; then
      trace "[send_to_spender_wallet_name] Node returned an invalid JSON-RPC response"
      result=""
      returncode=1
    elif ! printf '%s' "${result}" | jq -e '.error == null' >/dev/null 2>&1; then
      trace "[send_to_spender_wallet_name] Node responded, error found in response"
      returncode=1
    fi
  fi
  echo "${result}"
  trace_rc ${returncode}
  return ${returncode}
}

send_to_bitcoin_node() {
  trace "Entering send_to_bitcoin_node()..."
  local returncode
  local result
  local errorstring
  local node_url=${1}
  local config=${2}
  local data=${3}

  trace "[send_to_bitcoin_node] curl -m 20 -s --config ${config} -H \"Content-Type: application/json\" -d \"${data}\" ${node_url}"
  result=$(curl -m 20 -s --config "${config}" -H "Content-Type: application/json" -d "${data}" "${node_url}")
  returncode=$?
  trace_rc ${returncode}
  # trace "[send_to_bitcoin_node] result=${result}"

  if [ "${returncode}" -eq 0 ]; then
    # Node responded, let's see if we got an error message from the node
    # jq -e will have a return code of 1 if the supplied tag is null.
    errorstring=$(echo "${result}" | jq -e ".error")
    if [ "$?" -eq "0" ]; then
      # Error tag not null, so there's an error
      trace "[send_to_bitcoin_node] Node responded, error found in response: ${errorstring}"
      returncode=1
    else
      trace "[send_to_bitcoin_node] Node responded, no error found in response, yayy!"
    fi
  fi

  # Output response to stdout before exiting with return code
  echo "${result}"

  trace_rc ${returncode}
  return ${returncode}
}

send_batch_to_spender_node() {
  trace "Entering send_batch_to_spender_node()..."

  local walletname=${SPENDER_BTC_NODE_DEFAULT_WALLET}
  if [ -n "$2" ]; then
    walletname="spending${2}.dat"
  fi
  trace "[send_batch_to_spender_node]wallet: ${walletname}"

  send_batch_to_bitcoin_node "${SPENDER_BTC_NODE_RPC_URL}/${walletname}" "${SPENDER_BTC_NODE_RPC_CFG}" "$1"
  local returncode=$?
  trace_rc ${returncode}
  return ${returncode}
}

send_batch_to_bitcoin_node() {
  trace "Entering send_batch_to_bitcoin_node()..."
  local returncode
  local result
  local errorstring
  local node_url=${1}
  local config=${2}
  local body_file=${3}

  trace "[send_batch_to_bitcoin_node] curl -m 20 -s --config ${config} -H \"Content-Type: application/json\" -d @${body_file} ${node_url}"
  result=$(curl -m 20 -s --config "${config}" -H "Content-Type: application/json" -d @${body_file} "${node_url}")
  returncode=$?
  trace_rc ${returncode}
  trace "[send_batch_to_bitcoin_node] result=${result}"

  # Since there's an independant response for each batch item, we won't check for errors here.

  # Output response to stdout before exiting with return code
  echo "${result}"

  trace_rc ${returncode}
  return ${returncode}
}

case "${0}" in *sendtobitcoinnode.sh) send_to_bitcoin_node "$@";; esac
