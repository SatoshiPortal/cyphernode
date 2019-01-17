#!/bin/sh

. ./trace.sh
. ./sql.sh

do_callbacks() {
  (
  flock -x 200 || return 0

  trace "Entering do_callbacks()..."

  # Let's fetch all the watching addresses still being watched but not called back
  local callbacks=$(sql 'SELECT DISTINCT w.callback0conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime, w.id, is_replaceable, pub32_index, pub32, label, derivation_path FROM watching w LEFT JOIN watching_tx ON w.id = watching_id LEFT JOIN tx ON tx.id = tx_id LEFT JOIN watching_by_pub32 w32 ON watching_by_pub32_id = w32.id WHERE NOT calledback0conf AND watching_id NOT NULL AND w.callback0conf NOT NULL AND w.watching')
  trace "[do_callbacks] callbacks0conf=${callbacks}"

  local returncode
  local address
  local url
  local IFS=$'\n'
  for row in ${callbacks}
  do
    build_callback ${row}
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      address=$(echo "${row}" | cut -d '|' -f2)
      sql "UPDATE watching SET calledback0conf=1 WHERE address=\"${address}\""
      trace_rc $?
    fi
  done

  callbacks=$(sql 'SELECT DISTINCT w.callback1conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime, w.id, is_replaceable, pub32_index, pub32, label, derivation_path FROM watching w, watching_tx wt, tx t LEFT JOIN watching_by_pub32 w32 ON watching_by_pub32_id = w32.id WHERE w.id = watching_id AND tx_id = t.id AND NOT calledback1conf AND confirmations>0 AND w.callback1conf NOT NULL AND w.watching')
  trace "[do_callbacks] callbacks1conf=${callbacks}"

  for row in ${callbacks}
  do
    build_callback ${row}
    returncode=$?
    if [ "${returncode}" -eq 0 ]; then
      address=$(echo "${row}" | cut -d '|' -f2)
      sql "UPDATE watching SET calledback1conf=1, watching=0 WHERE address=\"${address}\""
      trace_rc $?
    fi
  done

  callbacks=$(sql "SELECT id, label, bolt11, callback_url, payment_hash, msatoshi, status, pay_index, msatoshi_received, paid_at, description, expires_at FROM ln_invoice WHERE NOT calledback AND callback_failed")
  trace "[do_callbacks LN] ln_callbacks=${callbacks}"

  for row in ${callbacks}
  do
    ln_manage_callback ${row}
    trace_rc $?
  done

  ) 200>./.callbacks.lock
}

ln_manage_callback() {
  trace "Entering ln_manage_callback()..."

  local row=$@
  trace "[ln_manage_callback] row=${row}"

  local id=$(echo "${row}" | cut -d '|' -f1)
  trace "[ln_manage_callback] id=${id}"
  local label=$(echo "${row}" | cut -d '|' -f2)
  trace "[ln_manage_callback] label=${label}"
  local bolt11=$(echo "${row}" | cut -d '|' -f3)
  trace "[ln_manage_callback] bolt11=${bolt11}"
  local callback_url=$(echo "${row}" | cut -d '|' -f4)
  trace "[ln_manage_callback] callback_url=${callback_url}"
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

  if [ -z "${callback_url}" ]; then
    # No callback url provided for that invoice
    sql "UPDATE ln_invoice SET calledback=1 WHERE id=\"${id}\""
    trace_rc $?
    return
  fi

  data="{\"id\":\"${id}\","
  data="${data}\"label\":\"${label}\","
  data="${data}\"bolt11\":\"${bolt11}\","
  data="${data}\"callback_url\":\"${callback_url}\","
  data="${data}\"payment_hash\":\"${payment_hash}\","
  data="${data}\"msatoshi\":${msatoshi},"
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
    sql "UPDATE ln_invoice SET calledback=1 WHERE id=\"${id}\""
    trace_rc $?
  else
    trace "[ln_manage_callback] callback failed: ${callback_url}"
    sql "UPDATE ln_invoice SET callback_failed=1 WHERE id=\"${id}\""
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

  # callback0conf, address, txid, vout, amount, confirmations, timereceived, fee, size, vsize, blockhash, blockheight, blocktime, w.id

  trace "[build_callback] row=${row}"
  id=$(echo "${row}" | cut -d '|' -f14)
  trace "[build_callback] id=${id}"
  url=$(echo "${row}" | cut -d '|' -f1)
  trace "[build_callback] url=${url}"
  address=$(echo "${row}" | cut -d '|' -f2)
  trace "[build_callback] address=${address}"
  txid=$(echo "${row}" | cut -d '|' -f3)
  trace "[build_callback] txid=${txid}"
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

  data="{\"id\":\"${id}\","
  data="${data}\"address\":\"${address}\","
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
  data="${data}\"is_replaceable\":${is_replaceable}"
  if [ -n "${blocktime}" ]; then
    data="${data},\"blockhash\":\"${blockhash}\","
    data="${data}\"blocktime\":\"$(date -Is -d @${blocktime})\","
    data="${data}\"blockheight\":${blockheight}"
  fi
  if [ -n "${pub32_index}" ]; then
    data="${data}\"pub32\":\"${pub32}\","
    data="${data}\"pub32_label\":\"${label}\","
    derivation_path=$(echo -e $derivation_path | sed -En "s/n/${pub32_index}/p")
    data="${data}\"pub32_derivation_path\":\"${derivation_path}\""
  fi
  data="${data}}"
  trace "[build_callback] data=${data}"

  curl_callback "${url}" "${data}"
  return $?
}

curl_callback() {
  trace "Entering curl_callback()..."

  local url=${1}
  local data=${2}
  local returncode

  trace "[curl_callback] curl -w \"%{http_code}\" -H \"Content-Type: application/json\" -H \"X-Forwarded-Proto: https\" -d \"${data}\" ${url}"
  rc=$(curl -w "%{http_code}" -H "Content-Type: application/json" -H "X-Forwarded-Proto: https" -d "${data}" ${url})
  returncode=$?
  trace "[curl_callback] HTTP return code=${rc}"
  trace_rc ${returncode}

  if [ "${returncode}" -eq "0" ]; then
    if [ "${rc}" -lt "400" ]; then
      return 0
    else
      return ${rc}
    fi
  else
    return ${returncode}
  fi
}

case "${0}" in *callbacks_job.sh) do_callbacks $@;; esac
