#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./notify.sh

elements_do_callbacks() {
  (
  flock -x 200 || return 0

  trace "Entering elements_do_callbacks()..."

  # Let's fetch all the watching addresses still being watched but not called back
  local callbacks=$(sql 'SELECT DISTINCT w.callback0conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime, w.id, is_replaceable, pub32_index, pub32, label, derivation_path, event_message, unblinded_address, watching_assetid, assetid FROM elements_watching w LEFT JOIN elements_watching_tx ON w.id = elements_watching_id LEFT JOIN elements_tx ON elements_tx.id = elements_tx_id LEFT JOIN elements_watching_by_pub32 w32 ON watching_by_pub32_id = w32.id WHERE NOT calledback0conf AND elements_watching_id NOT NULL AND w.callback0conf NOT NULL AND w.watching')
  trace "[elements_do_callbacks] callbacks0conf=${callbacks}"

  local returncode
  local address
  local url
  local IFS=$'\n'
  for row in ${callbacks}
  do
    elements_build_callback ${row}
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      address=$(echo "${row}" | cut -d '|' -f2)
      sql "UPDATE elements_watching SET calledback0conf=1 WHERE address=\"${address}\""
      trace_rc $?
    fi
  done

  callbacks=$(sql 'SELECT DISTINCT w.callback1conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime, w.id, is_replaceable, pub32_index, pub32, label, derivation_path, event_message, unblinded_address, watching_assetid, assetid FROM elements_watching w, elements_watching_tx wt, elements_tx t LEFT JOIN elements_watching_by_pub32 w32 ON watching_by_pub32_id = w32.id WHERE w.id = elements_watching_id AND elements_tx_id = t.id AND NOT calledback1conf AND confirmations>0 AND w.callback1conf NOT NULL AND w.watching')
  trace "[elements_do_callbacks] callbacks1conf=${callbacks}"

  for row in ${callbacks}
  do
    elements_build_callback ${row}
    returncode=$?
    if [ "${returncode}" -eq 0 ]; then
      address=$(echo "${row}" | cut -d '|' -f2)
      sql "UPDATE elements_watching SET calledback1conf=1, watching=0 WHERE address=\"${address}\""
      trace_rc $?
    fi
  done

  ) 200>./.elements_callbacks.lock
}

elements_build_callback() {
  trace "Entering elements_build_callback()..."

  local row=$@
  local id
  local url
  local data
  local address
  local unblinded_address
  local watching_assetid
  local assetid
  local txid
  local vout_n
  local sent_amount
  local confirmations
  local ts_firstseen
  local fee
  local size
  local vsize
  local blockhash
  local blocktime
  local blockheight

  local pub32_index
  local pub32
  local label
  local derivation_path

  local event_message

  # w.callback0conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime,
  # w.id, is_replaceable, pub32_index, pub32, label, derivation_path, event_message

  url=$(echo "${row}" | cut -d '|' -f1)
  trace "[elements_build_callback] url=${url}"
  if [ -z "${url}" ]; then
    # No callback url provided for that watch
    trace "[elements_build_callback] No callback url provided for that watch, skipping webhook call"
    return
  fi

  trace "[elements_build_callback] row=${row}"
  id=$(echo "${row}" | cut -d '|' -f14)
  trace "[elements_build_callback] id=${id}"
  address=$(echo "${row}" | cut -d '|' -f2)
  trace "[elements_build_callback] address=${address}"
  unblinded_address=$(echo "${row}" | cut -d '|' -f21)
  trace "[elements_build_callback] unblinded_address=${unblinded_address}"
  txid=$(echo "${row}" | cut -d '|' -f3)
  trace "[elements_build_callback] txid=${txid}"
  vout_n=$(echo "${row}" | cut -d '|' -f4)
  trace "[elements_build_callback] vout_n=${vout_n}"
  sent_amount=$(echo "${row}" | cut -d '|' -f5 | awk '{ printf "%.8f", $0 }')
  trace "[elements_build_callback] sent_amount=${sent_amount}"
  confirmations=$(echo "${row}" | cut -d '|' -f6)
  trace "[elements_build_callback] confirmations=${confirmations}"
  ts_firstseen=$(echo "${row}" | cut -d '|' -f7)
  trace "[elements_build_callback] ts_firstseen=${ts_firstseen}"

  # If node in pruned mode, we can't calculate the fees and then we don't want
  # to send 0.00000000 as fees but empty string to distinguish.
  fee=$(echo "${row}" | cut -d '|' -f8)
  if [ -n "${fee}" ]; then
    fee=$(echo "${fee}" | awk '{ printf "%.8f", $0 }')
  fi
  trace "[elements_build_callback] fee=${fee}"
  size=$(echo "${row}" | cut -d '|' -f9)
  trace "[elements_build_callback] size=${size}"
  vsize=$(echo "${row}" | cut -d '|' -f10)
  trace "[elements_build_callback] vsize=${vsize}"
  is_replaceable=$(echo "${row}" | cut -d '|' -f15)
  trace "[elements_build_callback] is_replaceable=${is_replaceable}"
  blockhash=$(echo "${row}" | cut -d '|' -f11)
  trace "[elements_build_callback] blockhash=${blockhash}"
  blockheight=$(echo "${row}" | cut -d '|' -f12)
  trace "[elements_build_callback] blockheight=${blockheight}"
  blocktime=$(echo "${row}" | cut -d '|' -f13)
  trace "[elements_build_callback] blocktime=${blocktime}"

  pub32_index=$(echo "${row}" | cut -d '|' -f16)
  trace "[elements_build_callback] pub32_index=${pub32_index}"
  if [ -n "${pub32_index}" ]; then
    pub32=$(echo "${row}" | cut -d '|' -f17)
    trace "[elements_build_callback] pub32=${pub32}"
    label=$(echo "${row}" | cut -d '|' -f18)
    trace "[elements_build_callback] label=${label}"
    derivation_path=$(echo "${row}" | cut -d '|' -f19)
    trace "[elements_build_callback] derivation_path=${derivation_path}"
  fi
  event_message=$(echo "${row}" | cut -d '|' -f20)
  trace "[elements_build_callback] event_message=${event_message}"
  unblinded_address=$(echo "${row}" | cut -d '|' -f21)
  trace "[elements_build_callback] unblinded_address=${unblinded_address}"
  watching_assetid=$(echo "${row}" | cut -d '|' -f22)
  trace "[elements_build_callback] watching_assetid=${watching_assetid}"
  assetid=$(echo "${row}" | cut -d '|' -f23)
  trace "[elements_build_callback] assetid=${assetid}"

  data="{\"id\":\"${id}\","
  data="${data}\"address\":\"${address}\","
  data="${data}\"unblinded_address\":\"${unblinded_address}\","
  data="${data}\"watchingAssetId\":\"${watching_assetid}\","
  data="${data}\"assetId\":\"${assetid}\","
  data="${data}\"hash\":\"${txid}\","
  data="${data}\"vout_n\":${vout_n},"
  data="${data}\"sent_amount\":${sent_amount},"
  data="${data}\"confirmations\":${confirmations},"
  data="${data}\"received\":\"$(date -Is -d @${ts_firstseen})\","
  data="${data}\"size\":${size},"
  data="${data}\"vsize\":${vsize},"
  if [ -n "${fee}" ]; then
    data="${data}\"fees\":${fee},"
  fi
  data="${data}\"is_replaceable\":${is_replaceable},"
  if [ -n "${blocktime}" ]; then
    data="${data}\"blockhash\":\"${blockhash}\","
    data="${data}\"blocktime\":\"$(date -Is -d @${blocktime})\","
    data="${data}\"blockheight\":${blockheight},"
  fi
  if [ -n "${pub32_index}" ]; then
    data="${data}\"pub32\":\"${pub32}\","
    data="${data}\"pub32_label\":\"${label}\","
    derivation_path=$(echo -e $derivation_path | sed -En "s/n/${pub32_index}/p")
    data="${data}\"pub32_derivation_path\":\"${derivation_path}\","
  fi
  data="${data}\"eventMessage\":\"${event_message}\"}"
  trace "[elements_build_callback] data=${data}"

  elements_curl_callback "${url}" "${data}"
  return $?
}

elements_curl_callback() {
  trace "Entering elements_curl_callback()..."

  local returncode

  notify_web "${1}" "${2}" ${TOR_ADDR_WATCH_WEBHOOKS}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}
