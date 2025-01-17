#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./elements_blockchainrpc.sh
. ./notify.sh
. ./elements_computefees.sh

elements_do_callbacks_txid() {
  trace "Entering elements_do_callbacks_txid()..."

  (
  local returncode
  local flock_output

  flock_output=$(flock --verbose --nonblock 8 2>&1)
  returncode=$?
  trace "[do_callbacks_txid] flock_output=${flock_output}"
  if [ "$returncode" -eq "0" ]; then
    # Let's check the 1-conf (newly mined) watched txid that are included in the new block...

    # Let's fetch all the watching txid still being watched but not called back
    local callbacks=$(sql "SELECT id, txid, callback1conf, 1 FROM elements_watching_by_txid WHERE watching AND callback1conf IS NOT NULL AND NOT calledback1conf")
    trace "[elements_do_callbacks_txid] callbacks1conf=${callbacks}"

    local address
    local url
    local id
    local IFS="
"
    for row in ${callbacks}
    do
      elements_build_callback_txid "${row}"
      returncode=$?
      trace_rc ${returncode}
      if [ "${returncode}" -eq "0" ]; then
        id=$(echo "${row}" | cut -d '|' -f1)
        sql "UPDATE elements_watching_by_txid SET calledback1conf=true WHERE id=${id}"
        trace_rc $?
      else
        trace "[elements_do_callbacks_txid] callback returncode has error, we don't flag as calledback yet."
      fi
    done

    # For the n-conf, let's only check the watched txids that are already at least 1-conf...

    local callbacks=$(sql "SELECT id, txid, callbackxconf, nbxconf FROM elements_watching_by_txid WHERE watching AND calledback1conf AND callbackxconf IS NOT NULL AND NOT calledbackxconf")
    trace "[elements_do_callbacks_txid] callbacksxconf=${callbacks}"

    for row in ${callbacks}
    do
      elements_build_callback_txid "${row}"
      returncode=$?
      trace_rc ${returncode}
      if [ "${returncode}" -eq "0" ]; then
        id=$(echo "${row}" | cut -d '|' -f1)
        sql "UPDATE elements_watching_by_txid SET calledbackxconf=true, watching=false WHERE id=${id}"
        trace_rc $?
      else
        trace "[elements_do_callbacks_txid] callback returncode has error, we don't flag as calledback yet."
      fi
    done
  else
    trace "[do_callbacks_txid]  Exiting flock"
  fi
  ) 8>./.elements_callbacks.lock
}

elements_build_callback_txid() {
  trace "Entering elements_build_callback_txid()..."

  local row="$@"
  local id
  local txid
  local url
  local nbxconf
  local blockhash
  local blockheight
  local confirmations
  local data
  local tx_raw_details

  # id, txid, url, nbconf

  trace "[elements_build_callback_txid] row=${row}"
  id=$(echo "${row}" | cut -d '|' -f1)
  trace "[elements_build_callback_txid] id=${id}"
  txid=$(echo "${row}" | cut -d '|' -f2)
  trace "[elements_build_callback_txid] txid=${txid}"
  url=$(echo "${row}" | cut -d '|' -f3)
  trace "[elements_build_callback_txid] url=${url}"
  nbxconf=$(echo "${row}" | cut -d '|' -f4)
  trace "[elements_build_callback_txid] nbxconf=${nbxconf}"

  tx_raw_details=$(elements_get_rawtransaction "${txid}")
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    confirmations=$(echo "${tx_raw_details}" | jq '.result.confirmations')
    if [ "${confirmations}" = "null" ]; then
      confirmations=0
    fi
    trace "[elements_build_callback_txid] confirmations=${confirmations}"

    if [ "${confirmations}" -ge "${nbxconf}" ]; then
      trace "[elements_build_callback_txid] Number of confirmations for tx is at least what we're looking for, callback time!"

      # Number of confirmations for transaction is at least what we want
      # Let's prepare the callback!

      data="{\"id\":${id},"
      data="${data}\"txid\":\"${txid}\","
      data="${data}\"confirmations\":${confirmations}"
      data="${data}}"
      trace "[elements_build_callback_txid] data=${data}"

      elements_curl_callback_txid "${url}" "${data}"
      return $?

    else
      trace "[elements_build_callback_txid] Number of confirmations for tx is not enough to call back."
      return 1
    fi
  else
    trace "[elements_build_callback_txid] Couldn't get tx from the Elements node."
    return 1
  fi
}

elements_curl_callback_txid() {
  trace "Entering elements_curl_callback_txid()..."

  local returncode
  local response

  response=$(notify_web "${1}" "${2}" "${TOR_TXID_WATCH_WEBHOOKS}")
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}
