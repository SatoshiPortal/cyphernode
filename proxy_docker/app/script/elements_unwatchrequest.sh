#!/bin/sh

. ./trace.sh
. ./sql.sh

elements_unwatchrequest() {
  trace "Entering elements_unwatchrequest()..."

  local request=${1}
  local address=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)
  local returncode
  trace "[elements_unwatchrequest] Unwatch request on address ${address}"

  sql "UPDATE elements_watching SET watching=0 WHERE address=\"${address}\""
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"elements_unwatch\",\"address\":\"${address}\"}"
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

  id=$(sql "SELECT id FROM elements_watching_by_pub32 WHERE pub32='${pub32}'")
  trace "[elements_unwatchpub32request] id: ${id}"

  sql "UPDATE elements_watching_by_pub32 SET watching=0 WHERE id=${id}"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE elements_watching SET watching=0 WHERE watching_by_pub32_id=\"${id}\""
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

  id=$(sql "SELECT id FROM elements_watching_by_pub32 WHERE label='${label}'")
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_unwatchpub32labelrequest] id: ${id}"

  sql "UPDATE elements_watching_by_pub32 SET watching=0 WHERE id=${id}"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE elements_watching SET watching=0 WHERE watching_by_pub32_id=\"${id}\""
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"elements_unwatchxpubbylabel\",\"label\":\"${label}\"}"
  trace "[elements_unwatchpub32labelrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}
