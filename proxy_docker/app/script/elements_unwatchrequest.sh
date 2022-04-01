#!/bin/sh

. ./trace.sh
. ./sql.sh

elements_unwatchrequest() {
  trace "Entering elements_unwatchrequest()..."

  local watchid=${1}
  local address=${2}
  local unconfirmedCallbackURL=${3}
  local confirmedCallbackURL=${4}
  local returncode

  trace "[elements_unwatchrequest] Unwatch request id ${watchid} on address \"${address}\" with url0conf \"${unconfirmedCallbackURL}\" and url1conf \"${confirmedCallbackURL}\""

  if [ "${watchid}" != "null" ]; then
    sql "UPDATE elements_watching SET watching=false WHERE id=${watchid}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatch\",\"id\":${watchid}}"
  else
    local cb0_where=
    local cb1_where=

    if [ "${unconfirmedCallbackURL}" != "null" ]; then
      cb0_where=" AND callback0conf='${unconfirmedCallbackURL}'"
    fi
    if [ "${confirmedCallbackURL}" != "null" ]; then
      cb1_where=" AND callback1conf='${confirmedCallbackURL}'"
    fi

    sql "UPDATE elements_watching SET watching=false WHERE address='${address}'${cb0_where}${cb1_where}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatch\",\"address\":\"${address}\",\"unconfirmedCallbackURL\":\"${unconfirmedCallbackURL}\",\"confirmedCallbackURL\":\"${confirmedCallbackURL}\"}"
  fi

  trace "[elements_unwatchrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}

elements_unwatchpub32request() {
  trace "Entering elements_unwatchpub32request()..."

  local request=${1}
  local pub32=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)
  local id
  local returncode
  trace "[elements_unwatchpub32request] Unwatch pub32 ${pub32}"

  sql "UPDATE elements_watching w SET watching=false FROM elements_watching_by_pub32 w32 WHERE w.elements_watching_by_pub32_id=w32.id AND pub32='${pub32}'"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE elements_watching_by_pub32 SET watching=false WHERE pub32='${pub32}'"
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"elements_unwatchxpubbyxpub\",\"pub32\":\"${pub32}\"}"
  trace "[elements_unwatchpub32request] responding=${data}"

  echo "${data}"

  return ${returncode}
}

elements_unwatchpub32labelrequest() {
  trace "Entering elements_unwatchpub32labelrequest()..."

  local request=${1}
  local label=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)
  local id
  local returncode
  trace "[elements_unwatchpub32labelrequest] Unwatch xpub label ${label}"

  sql "UPDATE elements_watching w SET watching=false FROM elements_watching_by_pub32 w32 WHERE w.elements_watching_by_pub32_id=w32.id AND w32.label='${label}'"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE elements_watching_by_pub32 SET watching=false WHERE label='${label}'"
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"elements_unwatchxpubbylabel\",\"label\":\"${label}\"}"
  trace "[elements_unwatchpub32labelrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}

elements_unwatchtxidrequest() {
  trace "Entering elements_unwatchtxidrequest()..."

  local watchid=${1}
  local txid=${2}

  local unconfirmedCallbackURL=${3}
  local uc_pg uc_json
  [ "${unconfirmedCallbackURL}" = "null" ] && uc_pg=" IS NULL" && uc_json="null" || uc_pg="='${unconfirmedCallbackURL}'" && uc_json="\"${unconfirmedCallbackURL}\""

  local confirmedCallbackURL=${4}
  local c_pg c_json
  [ "${confirmedCallbackURL}" = "null" ] && c_pg=" IS NULL" && c_json="null" || c_pg="='${confirmedCallbackURL}'" && c_json="\"${confirmedCallbackURL}\""

  local returncode
  trace "[elements_unwatchtxidrequest] elements_unwatch request id ${watchid} on txid \"${txid}\" with url0conf \"${unconfirmedCallbackURL}\" and url1conf \"${confirmedCallbackURL}\""

  if [ "${watchid}" != "null" ]; then
    sql "UPDATE elements_watching_by_txid SET watching=false WHERE id=${watchid}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatchtxid\",\"id\":${watchid}}"
  else
    sql "UPDATE elements_watching_by_txid SET watching=false WHERE txid='${txid}' AND callback0conf${uc_pg} AND callback1conf${c_pg}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatchtxid\",\"txid\":\"${txid}\",\"unconfirmedCallbackURL\":${uc_json},\"confirmedCallbackURL\":${c_json}}"
  fi

  trace "[elements_unwatchtxidrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}
