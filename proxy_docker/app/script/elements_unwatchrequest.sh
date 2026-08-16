#!/bin/sh

. ./trace.sh
. ./sql.sh

elements_unwatchrequest() {
  trace "Entering elements_unwatchrequest()..."

  local watchid=${1}
  local address=${2}
  local unconfirmedCallbackURL=${3}
  local confirmedCallbackURL=${4}
  local assetId=${5:-}
  local returncode

  trace "[elements_unwatchrequest] Unwatch request id ${watchid} on address \"${address}\" with url0conf \"${unconfirmedCallbackURL}\" and url1conf \"${confirmedCallbackURL}\" asset \"${assetId}\""

  if [ "${watchid}" != "null" ]; then
    case "${watchid}" in
      ''|*[!0-9]*)
        echo '{"result":null,"error":{"code":-8,"message":"id must be a non-negative integer"}}'
        return 1
        ;;
    esac
    sql "UPDATE elements_watching SET watching=false WHERE id=${watchid}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatch\",\"id\":${watchid}}"
  else
    local cb0_where=
    local cb1_where=
    local asset_where=
    local address_pg address_json cb0_json cb1_json asset_json

    if [ "${address}" = "null" ] || [ -z "${address}" ]; then
      echo '{"result":null,"error":{"code":-5,"message":"address or id required"}}'
      return 1
    fi
    address_pg=$(sql_string_literal "${address}")
    address_json=$(json_string_literal "${address}")

    # An asset-scoped watch identity means one address can carry several
    # watches. When the caller names an asset, target only that one; otherwise
    # preserve the historical behavior of clearing every asset on the address.
    if [ "${assetId}" != "null" ] && [ -n "${assetId}" ]; then
      asset_where=" AND watching_assetid=$(sql_string_literal "${assetId}")"
      asset_json=$(json_string_literal "${assetId}")
    else
      asset_json="null"
    fi

    if [ "${unconfirmedCallbackURL}" != "null" ]; then
      cb0_where=" AND callback0conf=$(sql_string_literal "${unconfirmedCallbackURL}")"
      cb0_json=$(json_string_literal "${unconfirmedCallbackURL}")
    else
      cb0_json="null"
    fi
    if [ "${confirmedCallbackURL}" != "null" ]; then
      cb1_where=" AND callback1conf=$(sql_string_literal "${confirmedCallbackURL}")"
      cb1_json=$(json_string_literal "${confirmedCallbackURL}")
    else
      cb1_json="null"
    fi

    # Match either the confidential or the unconfidential form: watches are
    # found by (address OR unblinded_address) elsewhere, and the watch response
    # returns both, so a caller may hold either one.
    sql "UPDATE elements_watching SET watching=false WHERE (address=${address_pg} OR unblinded_address=${address_pg})${cb0_where}${cb1_where}${asset_where}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatch\",\"address\":${address_json},\"unconfirmedCallbackURL\":${cb0_json},\"confirmedCallbackURL\":${cb1_json},\"assetId\":${asset_json}}"
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
  local pub32_pg pub32_json
  pub32_pg=$(sql_string_literal "${pub32}")
  pub32_json=$(json_string_literal "${pub32}")
  trace "[elements_unwatchpub32request] Unwatch pub32 ${pub32}"

  sql "UPDATE elements_watching w SET watching=false FROM elements_watching_by_pub32 w32 WHERE w.elements_watching_by_pub32_id=w32.id AND pub32=${pub32_pg}"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE elements_watching_by_pub32 SET watching=false WHERE pub32=${pub32_pg}"
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"elements_unwatchxpubbyxpub\",\"pub32\":${pub32_json}}"
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
  local label_pg label_json
  label_pg=$(sql_string_literal "${label}")
  label_json=$(json_string_literal "${label}")
  trace "[elements_unwatchpub32labelrequest] Unwatch xpub label ${label}"

  sql "UPDATE elements_watching w SET watching=false FROM elements_watching_by_pub32 w32 WHERE w.elements_watching_by_pub32_id=w32.id AND w32.label=${label_pg}"
  returncode=$?
  trace_rc ${returncode}

  sql "UPDATE elements_watching_by_pub32 SET watching=false WHERE label=${label_pg}"
  returncode=$?
  trace_rc ${returncode}

  data="{\"event\":\"elements_unwatchxpubbylabel\",\"label\":${label_json}}"
  trace "[elements_unwatchpub32labelrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}

elements_unwatchtxidrequest() {
  trace "Entering elements_unwatchtxidrequest()..."

  local watchid=${1}
  local txid=${2}

  local conf1CallbackURL=${3}
  local c1_pg c1_json
  if [ "${conf1CallbackURL}" = "null" ]; then
    c1_pg=" IS NULL"
    c1_json="null"
  else
    c1_pg="=$(sql_string_literal "${conf1CallbackURL}")"
    c1_json=$(json_string_literal "${conf1CallbackURL}")
  fi

  local confirmedXCallbackURL=${4}
  local cx_pg cx_json
  if [ "${confirmedXCallbackURL}" = "null" ]; then
    cx_pg=" IS NULL"
    cx_json="null"
  else
    cx_pg="=$(sql_string_literal "${confirmedXCallbackURL}")"
    cx_json=$(json_string_literal "${confirmedXCallbackURL}")
  fi

  local returncode
  trace "[unwatchtxidrequest] elements_unwatch request id ${watchid} on txid \"${txid}\" with url1conf \"${conf1CallbackURL}\" and urlxconf \"${confirmedXCallbackURL}\""

  if [ "${watchid}" != "null" ]; then
    case "${watchid}" in
      ''|*[!0-9]*)
        echo '{"result":null,"error":{"code":-8,"message":"id must be a non-negative integer"}}'
        return 1
        ;;
    esac
    sql "UPDATE elements_watching_by_txid SET watching=false WHERE id=${watchid}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatchtxid\",\"id\":${watchid}}"
  else
    if [ "${#txid}" -ne 64 ]; then
      echo '{"result":null,"error":{"code":-8,"message":"txid must be a 64-character hexadecimal string"}}'
      return 1
    fi
    case "${txid}" in
      *[!0-9a-fA-F]*)
        echo '{"result":null,"error":{"code":-8,"message":"txid must be a 64-character hexadecimal string"}}'
        return 1
        ;;
    esac
    txid=$(echo "${txid}" | tr 'A-F' 'a-f')
    local txid_pg txid_json
    txid_pg=$(sql_string_literal "${txid}")
    txid_json=$(json_string_literal "${txid}")

    sql "UPDATE elements_watching_by_txid SET watching=false WHERE txid=${txid_pg} AND callback1conf${c1_pg} AND callbackxconf${cx_pg}"
    returncode=$?
    trace_rc ${returncode}

    data="{\"event\":\"elements_unwatchtxid\",\"txid\":${txid_json},\"confirmedCallbackURL\":${c1_json},\"xconfCallbackURL\":${cx_json}}"
  fi

  trace "[elements_unwatchtxidrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}
