#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./blockchainrpc.sh
. ./computefees.sh

do_callbacks_txid() {
  trace "Entering do_callbacks_txid()..."

  (
  local flock_output=$(flock --verbose --nonblock 8) || (trace "[do_callbacks_txid] Exiting - flock_output=${flock_output}" && return 0)
  trace "[do_callbacks_txid] flock_output=${flock_output}"

  # Let's check the 1-conf (newly mined) watched txid that are included in the new block...

  # Let's fetch all the watching txid still being watched but not called back
  local callbacks=$(sql "SELECT id, txid, callback1conf, 1 FROM watching_by_txid WHERE watching AND callback1conf IS NOT NULL AND NOT calledback1conf")
  trace "[do_callbacks_txid] callbacks1conf=${callbacks}"

  local returncode
  local address
  local url
  local id
  local IFS="
"
  for row in ${callbacks}
  do
    build_callback_txid "${row}"
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq "0" ]; then
      id=$(echo "${row}" | cut -d '|' -f1)
      sql "UPDATE watching_by_txid SET calledback1conf=true WHERE id=${id}"
      trace_rc $?
    else
      trace "[do_callbacks_txid] callback returncode has error, we don't flag as calledback yet."
    fi
  done

  # For the n-conf, let's only check the watched txids that are already at least 1-conf...

  local callbacks=$(sql "SELECT id, txid, callbackxconf, nbxconf FROM watching_by_txid WHERE watching AND calledback1conf AND callbackxconf IS NOT NULL AND NOT calledbackxconf")
  trace "[do_callbacks_txid] callbacksxconf=${callbacks}"

  for row in ${callbacks}
  do
    build_callback_txid "${row}"
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq "0" ]; then
      id=$(echo "${row}" | cut -d '|' -f1)
      sql "UPDATE watching_by_txid SET calledbackxconf=true, watching=false WHERE id=${id}"
      trace_rc $?
    else
      trace "[do_callbacks_txid] callback returncode has error, we don't flag as calledback yet."
    fi
  done

  ) 8>./.callbacks.lock
}

build_callback_txid() {
  trace "Entering build_callback_txid()..."

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

  trace "[build_callback_txid] row=${row}"
  id=$(echo "${row}" | cut -d '|' -f1)
  trace "[build_callback_txid] id=${id}"
  txid=$(echo "${row}" | cut -d '|' -f2)
  trace "[build_callback_txid] txid=${txid}"
  url=$(echo "${row}" | cut -d '|' -f3)
  trace "[build_callback_txid] url=${url}"
  nbxconf=$(echo "${row}" | cut -d '|' -f4)
  trace "[build_callback_txid] nbxconf=${nbxconf}"

  tx_raw_details=$(get_rawtransaction "${txid}")
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    confirmations=$(echo "${tx_raw_details}" | jq '.result.confirmations')
    if [ "${confirmations}" = "null" ]; then
      confirmations=0
    fi
    trace "[build_callback_txid] confirmations=${confirmations}"

    if [ "${confirmations}" -ge "${nbxconf}" ]; then
      trace "[build_callback_txid] Number of confirmations for tx is at least what we're looking for, callback time!"

      # Sometimes raw tx are too long to be passed as paramater, so let's write
      # it to a temp file for it to be read by sqlite3 and then delete the file
      echo "${tx_raw_details}" | jq -Mc '.result' > rawtx-${txid}-$$.blob

      # Number of confirmations for transaction is at least what we want
      # Let's prepare the callback!

      local tx_hash=$(echo "${tx_raw_details}" | jq '.result.hash')
      trace "[build_callback_txid] tx_hash=${tx_hash}"
      local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
      trace "[build_callback_txid] tx_size=${tx_size}"
      local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
      trace "[build_callback_txid] tx_vsize=${tx_vsize}"
      local fees=$(compute_fees "${txid}")
      trace "[build_callback_txid] fees=${fees}"
      local tx_blockhash=$(echo "${tx_raw_details}" | jq '.result.blockhash')
      trace "[build_callback_txid] tx_blockhash=${tx_blockhash}"
      local tx_blockheight=$(get_block_info "$(echo ${tx_blockhash} | tr -d '"')" | jq '.result.height')
      trace "[build_callback_txid] tx_blockheight=${tx_blockheight}"
      local tx_blocktime=$(echo "${tx_raw_details}" | jq '.result.blocktime')
      trace "[build_callback_txid] tx_blocktime=${tx_blocktime}"

      data="{\"id\":\"${id}\","
      data="${data}\"txid\":\"${txid}\","
      data="${data}\"hash\":${tx_hash},"
      data="${data}\"confirmations\":${confirmations},"
      data="${data}\"size\":${tx_size},"
      data="${data}\"vsize\":${tx_vsize},"
      data="${data}\"fees\":${fees},"
      data="${data}\"blockhash\":${tx_blockhash},"
      data="${data}\"blocktime\":\"$(date -Is -d @${tx_blocktime})\","
      data="${data}\"blockheight\":${tx_blockheight}}"
      trace "[build_callback_txid] data=${data}"

      curl_callback_txid "${url}" "${data}"
      returncode=$?

      # Delete the temp file containing the raw tx (see above)
      rm rawtx-${txid}-$$.blob

      return ${returncode}
    else
      trace "[build_callback_txid] Number of confirmations for tx is not enough to call back."
      return 1
    fi
  else
    trace "[build_callback_txid] Couldn't get tx from the Bitcoin node."
    return 1
  fi
}

curl_callback_txid() {
  trace "Entering curl_callback_txid()..."

  local returncode
  local response

  response=$(notify_web "${1}" "${2}" "${TOR_TXID_WATCH_WEBHOOKS}")
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}
