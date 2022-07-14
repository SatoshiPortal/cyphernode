#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./notify.sh

do_callbacks() {
  (
  flock -x 8 || return 0

  trace "Entering do_callbacks()..."

  # If called because we received a confirmation for a specific txid, let's only
  # process that txid-related callbacks...
  local txid=${1}
  local txid_where
  if [ -n "${txid}" ]; then
    trace "[do_callbacks] txid=${txid}"
    txid_where=" AND txid='${txid}'"
  fi

  # Let's fetch all the watching addresses still being watched but not called back
  local callbacks=$(sql "SELECT DISTINCT w.callback0conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime, w.id, is_replaceable::text, pub32_index, pub32, w.label, derivation_path, event_message, hash FROM watching w LEFT JOIN watching_tx ON w.id = watching_id LEFT JOIN tx ON tx.id = tx_id LEFT JOIN watching_by_pub32 w32 ON w.watching_by_pub32_id = w32.id WHERE NOT calledback0conf AND watching_id IS NOT NULL AND w.callback0conf IS NOT NULL AND w.watching${txid_where}")
  trace "[do_callbacks] callbacks0conf=${callbacks}"

  local returncode
  local address
  local url
  local IFS="
"
  for row in ${callbacks}
  do
    build_callback ${row}
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      address=$(echo "${row}" | cut -d '|' -f2)
      sql "UPDATE watching SET calledback0conf=true WHERE address='${address}'"
      trace_rc $?
    fi
  done

  callbacks=$(sql "SELECT DISTINCT w.callback1conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime, w.id, is_replaceable::text, pub32_index, pub32, w.label, derivation_path, event_message, hash FROM watching w JOIN watching_tx wt ON w.id = wt.watching_id JOIN tx t ON wt.tx_id = t.id LEFT JOIN watching_by_pub32 w32 ON watching_by_pub32_id = w32.id WHERE NOT calledback1conf AND confirmations>0 AND w.callback1conf IS NOT NULL AND w.watching${txid_where}")
  trace "[do_callbacks] callbacks1conf=${callbacks}"

  for row in ${callbacks}
  do
    build_callback ${row}
    returncode=$?
    if [ "${returncode}" -eq 0 ]; then
      address=$(echo "${row}" | cut -d '|' -f2)
      sql "UPDATE watching SET calledback1conf=true, watching=false WHERE address='${address}'"
      trace_rc $?
    fi
  done

  if [ -z "${txid}" ]; then
    trace "[do_callbacks] Processing LN callbacks..."

    callbacks=$(sql "SELECT id, label, bolt11, callback_url, payment_hash, msatoshi, status, pay_index, msatoshi_received, paid_at, description, expires_at FROM ln_invoice WHERE NOT calledback AND callback_failed")
    trace "[do_callbacks] ln_callbacks=${callbacks}"

    for row in ${callbacks}
    do
      ln_manage_callback ${row}
      trace_rc $?
    done
  else
    trace "[do_callbacks] called for a specific txid, skipping LN callbacks"
  fi

  ) 8>./.callbacks.lock
}

ln_manage_callback() {
  trace "Entering ln_manage_callback()..."

  local row=$@
  trace "[ln_manage_callback] row=${row}"

  local id=$(echo "${row}" | cut -d '|' -f1)
  trace "[ln_manage_callback] id=${id}"
  local callback_url=$(echo "${row}" | cut -d '|' -f4)
  trace "[ln_manage_callback] callback_url=${callback_url}"

  if [ -z "${callback_url}" ]; then
    # No callback url provided for that invoice
    trace "[ln_manage_callback] No callback url provided for that invoice"
    sql "UPDATE ln_invoice SET calledback=true WHERE id=${id}"
    trace_rc $?
    return
  fi

  local label=$(echo "${row}" | cut -d '|' -f2)
  trace "[ln_manage_callback] label=${label}"
  local bolt11=$(echo "${row}" | cut -d '|' -f3)
  trace "[ln_manage_callback] bolt11=${bolt11}"
  local payment_hash=$(echo "${row}" | cut -d '|' -f5)
  trace "[ln_manage_callback] payment_hash=${payment_hash}"
  local msatoshi=$(echo "${row}" | cut -d '|' -f6)
  trace "[ln_manage_callback] msatoshi=${msatoshi}"
  local status=$(echo "${row}" | cut -d '|' -f7)
  trace "[ln_manage_callback] status=${status}"
  local pay_index=$(echo "${row}" | cut -d '|' -f8)
  trace "[ln_manage_callback] pay_index=${pay_index}"
  local msatoshi_received=$(echo "${row}" | cut -d '|' -f9)
  trace "[ln_manage_callback] msatoshi_received=${msatoshi_received}"
  local paid_at=$(echo "${row}" | cut -d '|' -f10)
  trace "[ln_manage_callback] paid_at=${paid_at}"
  local description=$(echo "${row}" | cut -d '|' -f11)
  trace "[ln_manage_callback] description=${description}"
  local expires_at=$(echo "${row}" | cut -d '|' -f12)
  trace "[ln_manage_callback] expires_at=${expires_at}"
  local returncode

  # {
  #   "id":"",
  #   "label":"",
  #   "bolt11":"",
  #   "callback_url":"",
  #   "payment_hash":"",
  #   "msatoshi":,
  #   "status":"",
  #   "pay_index":,
  #   "msatoshi_received":,
  #   "paid_at":,
  #   "description":"",
  #   "expires_at":
  # }

  data="{\"id\":${id},"
  data="${data}\"label\":\"${label}\","
  data="${data}\"bolt11\":\"${bolt11}\","
  data="${data}\"callback_url\":\"${callback_url}\","
  data="${data}\"payment_hash\":\"${payment_hash}\","
  if [ -n "${msatoshi}" ]; then
    data="${data}\"msatoshi\":${msatoshi},"
  fi
  data="${data}\"status\":\"${status}\","
  data="${data}\"pay_index\":${pay_index},"
  data="${data}\"msatoshi_received\":${msatoshi_received},"
  data="${data}\"paid_at\":${paid_at},"
  data="${data}\"description\":\"${description}\","
  data="${data}\"expires_at\":${expires_at}}"
  trace "[ln_manage_callback] data=${data}"

  curl_callback "${callback_url}" "${data}"
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    sql "UPDATE ln_invoice SET calledback=true WHERE id=${id}"
    trace_rc $?
  else
    trace "[ln_manage_callback] callback failed: ${callback_url}"
    sql "UPDATE ln_invoice SET callback_failed=true WHERE id=${id}"
    trace_rc $?
  fi

  return ${returncode}
}

build_callback() {
  trace "Entering build_callback()..."

  local row=$@
  local id
  local url
  local data
  local address
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
  local hash

  # w.callback0conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime,
  # w.id, is_replaceable, pub32_index, pub32, label, derivation_path, event_message

  url=$(echo "${row}" | cut -d '|' -f1)
  trace "[build_callback] url=${url}"
  if [ -z "${url}" ]; then
    # No callback url provided for that watch
    trace "[build_callback] No callback url provided for that watch, skipping webhook call"
    return
  fi

  trace "[build_callback] row=${row}"
  id=$(echo "${row}" | cut -d '|' -f14)
  trace "[build_callback] id=${id}"
  address=$(echo "${row}" | cut -d '|' -f2)
  trace "[build_callback] address=${address}"
  txid=$(echo "${row}" | cut -d '|' -f3)
  trace "[build_callback] txid=${txid}"
  hash=$(echo "${row}" | cut -d '|' -f21)
  trace "[build_callback] hash=${hash}"
  vout_n=$(echo "${row}" | cut -d '|' -f4)
  trace "[build_callback] vout_n=${vout_n}"
  sent_amount=$(echo "${row}" | cut -d '|' -f5 | awk '{ printf "%.8f", $0 }')
  trace "[build_callback] sent_amount=${sent_amount}"
  confirmations=$(echo "${row}" | cut -d '|' -f6)
  trace "[build_callback] confirmations=${confirmations}"
  ts_firstseen=$(echo "${row}" | cut -d '|' -f7)
  trace "[build_callback] ts_firstseen=${ts_firstseen}"

  # If node in pruned mode, we can't calculate the fees and then we don't want
  # to send 0.00000000 as fees but empty string to distinguish.
  fee=$(echo "${row}" | cut -d '|' -f8)
  if [ -n "${fee}" ]; then
    fee=$(echo "${fee}" | awk '{ printf "%.8f", $0 }')
  fi
  trace "[build_callback] fee=${fee}"
  size=$(echo "${row}" | cut -d '|' -f9)
  trace "[build_callback] size=${size}"
  vsize=$(echo "${row}" | cut -d '|' -f10)
  trace "[build_callback] vsize=${vsize}"
  is_replaceable=$(echo "${row}" | cut -d '|' -f15)
  trace "[build_callback] is_replaceable=${is_replaceable}"
  blockhash=$(echo "${row}" | cut -d '|' -f11)
  trace "[build_callback] blockhash=${blockhash}"
  blockheight=$(echo "${row}" | cut -d '|' -f12)
  trace "[build_callback] blockheight=${blockheight}"
  blocktime=$(echo "${row}" | cut -d '|' -f13)
  trace "[build_callback] blocktime=${blocktime}"

  pub32_index=$(echo "${row}" | cut -d '|' -f16)
  trace "[build_callback] pub32_index=${pub32_index}"
  if [ -n "${pub32_index}" ]; then
    pub32=$(echo "${row}" | cut -d '|' -f17)
    trace "[build_callback] pub32=${pub32}"
    label=$(echo "${row}" | cut -d '|' -f18)
    trace "[build_callback] label=${label}"
    derivation_path=$(echo "${row}" | cut -d '|' -f19)
    trace "[build_callback] derivation_path=${derivation_path}"
  fi
  event_message=$(echo "${row}" | cut -d '|' -f20)
  trace "[build_callback] event_message=${event_message}"

  data="{\"id\":${id},"
  data="${data}\"address\":\"${address}\","
  data="${data}\"txid\":\"${txid}\","
  data="${data}\"hash\":\"${hash}\","
  data="${data}\"vout_n\":${vout_n},"
  data="${data}\"sent_amount\":${sent_amount},"
  data="${data}\"confirmations\":${confirmations},"
  data="${data}\"received\":\"$(date -Is -d @${ts_firstseen})\","
  data="${data}\"size\":${size},"
  data="${data}\"vsize\":${vsize},"
  if [ -n "${fee}" ]; then
    data="${data}\"fees\":${fee},"
  fi
  data="${data}\"replaceable\":${is_replaceable},"
  if [ -n "${blocktime}" ]; then
    data="${data}\"blockhash\":\"${blockhash}\","
    data="${data}\"blocktime\":\"$(date -Is -d @${blocktime})\","
    data="${data}\"blockheight\":${blockheight},"
  fi
  if [ -n "${pub32_index}" ]; then
    data="${data}\"pub32\":\"${pub32}\","
    data="${data}\"pub32_label\":\"${label}\","
    derivation_path=$(echo $derivation_path | sed -En "s/n/${pub32_index}/p")
    data="${data}\"pub32_derivation_path\":\"${derivation_path}\","
  fi
  data="${data}\"eventMessage\":\"${event_message}\"}"
  trace "[build_callback] data=${data}"

  curl_callback "${url}" "${data}"
  return $?
}

curl_callback() {
  trace "Entering curl_callback()..."

  local returncode
  local response

  response=$(notify_web "${1}" "${2}" ${TOR_ADDR_WATCH_WEBHOOKS})
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

case "${0}" in *callbacks_job.sh) do_callbacks $@;; esac
