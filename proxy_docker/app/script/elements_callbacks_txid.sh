#!/bin/sh

. ./trace.sh
. ./sql.sh

elements_do_callbacks_txid() {
  (
  flock -x 200 || return 0

  trace "Entering elements_do_callbacks_txid()..."

  # Let's fetch all the watching txid still being watched but not called back
  local callbacks=$(sql 'SELECT id, txid, callback1conf, 1 FROM elements_watching_by_txid WHERE watching AND callback1conf NOT NULL AND NOT calledback1conf')
  trace "[elements_do_callbacks_txid] callbacks1conf=${callbacks}"

  local returncode
  local address
  local url
  local id
  local IFS=$'\n'
  for row in ${callbacks}
  do
    elements_build_callback_txid ${row}
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      id=$(echo "${row}" | cut -d '|' -f1)
      sql "UPDATE elements_watching_by_txid SET calledback1conf=1 WHERE id=\"${id}\""
      trace_rc $?
    else
      trace "[elements_do_callbacks_txid] callback returncode has error, we don't flag as calledback yet."
    fi
  done

  local callbacks=$(sql 'SELECT id, txid, callbackxconf, nbxconf FROM elements_watching_by_txid WHERE watching AND calledback1conf AND callbackxconf NOT NULL AND NOT calledbackxconf')
  trace "[elements_do_callbacks_txid] callbacksxconf=${callbacks}"

  for row in ${callbacks}
  do
    elements_build_callback_txid ${row}
    returncode=$?
    if [ "${returncode}" -eq 0 ]; then
      id=$(echo "${row}" | cut -d '|' -f1)
      sql "UPDATE elements_watching_by_txid SET calledbackxconf=1, watching=0 WHERE id=\"${id}\""
      trace_rc $?
    else
      trace "[elements_do_callbacks_txid] callback returncode has error, we don't flag as calledback yet."
    fi
  done

  ) 200>./.elements_callbacks.lock
}

elements_build_callback_txid() {
  trace "Entering elements_build_callback_txid()..."

  local row=$@
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

  tx_raw_details=$(elements_get_rawtransaction ${txid})
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    confirmations=$(echo "${tx_raw_details}" | jq '.result.confirmations')
    trace "[elements_build_callback_txid] confirmations=${confirmations}"

    if [ "${confirmations}" -ge "${nbxconf}" ]; then
      trace "[elements_build_callback_txid] Number of confirmations for tx is at least what we're looking for, callback time!"
      # Number of confirmations for transaction is at least what we want
      # Let's prepare the callback!

  #    blockhash=$(echo "${tx_raw_details}" | jq '.result.blockhash')
  #    trace "[build_callback_txid] blockhash=${blockhash}"
  #    blockheight=$(get_block_info $(echo "${blockhash}" | tr -d '"') | jq '.result.height')
  #    trace "[build_callback_txid] blockheight=${blockheight}"

      data="{\"id\":\"${id}\","
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
  fi
}

elements_curl_callback_txid() {
  trace "Entering elements_curl_callback_txid()..."

  local returncode

  notify_web "${1}" "${2}" ${TOR_TXID_WATCH_WEBHOOKS}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}
