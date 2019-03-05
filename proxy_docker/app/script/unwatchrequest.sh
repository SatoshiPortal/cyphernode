#!/bin/sh

. ./trace.sh
. ./sql.sh

unwatchrequest() {
  trace "Entering unwatchrequest()..."

  local request=${1}
  local address=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)
  local returncode
  trace "[unwatchrequest] Unwatch request on address ${address}"

  sql "UPDATE watching SET watching=0 WHERE address=\"${address}\""
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"unwatch\",\"address\":\"${address}\"}"
  trace "[unwatchrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}

unwatchpub32request() {
  trace "Entering unwatchpub32request()..."

  local request=${1}
  local pub32=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)
  local id
  local returncode
  trace "[unwatchpub32request] Unwatch pub32 ${pub32}"

  id=$(sql "SELECT id FROM watching_by_pub32 WHERE pub32='${pub32}'")
  trace "[unwatchpub32request] id: ${id}"

  sql "UPDATE watching_by_pub32 SET watching=0 WHERE id=${id}"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE watching SET watching=0 WHERE watching_by_pub32_id=\"${id}\""
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"unwatchxpubbyxpub\",\"pub32\":\"${pub32}\"}"
  trace "[unwatchpub32request] responding=${data}"

  echo "${data}"

  return ${returncode}
}

unwatchpub32labelrequest() {
  trace "Entering unwatchpub32labelrequest()..."

  local request=${1}
  local label=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)
  local id
  local returncode
  trace "[unwatchpub32labelrequest] Unwatch xpub label ${label}"

  id=$(sql "SELECT id FROM watching_by_pub32 WHERE label='${label}'")
  returncode=$?
  trace_rc ${returncode}
  trace "[unwatchpub32labelrequest] id: ${id}"

  sql "UPDATE watching_by_pub32 SET watching=0 WHERE id=${id}"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE watching SET watching=0 WHERE watching_by_pub32_id=\"${id}\""
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"unwatchxpubbylabel\",\"label\":\"${label}\"}"
  trace "[unwatchpub32labelrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}
