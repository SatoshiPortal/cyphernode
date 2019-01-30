#!/bin/sh

. ./trace.sh
. ./importaddress.sh
. ./sql.sh
. ./sendtobitcoinnode.sh
. ./bitcoin.sh

watchrequest() {
  trace "Entering watchrequest()..."

  local returncode
  local request=${1}
  local address=$(echo "${request}" | jq ".address" | tr -d '"')
  local cb0conf_url=$(echo "${request}" | jq ".unconfirmedCallbackURL" | tr -d '"')
  local cb1conf_url=$(echo "${request}" | jq ".confirmedCallbackURL" | tr -d '"')
  local imported
  local inserted
  local id_inserted
  local result
  trace "[watchrequest] Watch request on address (${address}), cb 0-conf (${cb0conf_url}), cb 1-conf (${cb1conf_url})"

  result=$(importaddress_rpc "${address}")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    imported=1
  else
    imported=0
  fi

  sql "INSERT OR REPLACE INTO watching (address, watching, callback0conf, callback1conf, imported) VALUES (\"${address}\", 1, \"${cb0conf_url}\", \"${cb1conf_url}\", ${imported})"
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    inserted=1
    id_inserted=$(sql "SELECT id FROM watching WHERE address='${address}'")
    trace "[watchrequest] id_inserted: ${id_inserted}"
  else
    inserted=0
  fi

  local fees2blocks
  local fees6blocks
  local fees36blocks
  local fees144blocks
  fees2blocks=$(getestimatesmartfee 2)
  trace_rc $?
  fees6blocks=$(getestimatesmartfee 6)
  trace_rc $?
  fees36blocks=$(getestimatesmartfee 36)
  trace_rc $?
  fees144blocks=$(getestimatesmartfee 144)
  trace_rc $?

  local data="{\"id\":\"${id_inserted}\",
  \"event\":\"watch\",
  \"imported\":\"${imported}\",
  \"inserted\":\"${inserted}\",
  \"address\":\"${address}\",
  \"unconfirmedCallbackURL\":\"${cb0conf_url}\",
  \"confirmedCallbackURL\":\"${cb1conf_url}\",
  \"estimatesmartfee2blocks\":\"${fees2blocks}\",
  \"estimatesmartfee6blocks\":\"${fees6blocks}\",
  \"estimatesmartfee36blocks\":\"${fees36blocks}\",
  \"estimatesmartfee144blocks\":\"${fees144blocks}\"}"
  trace "[watchrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}

watchpub32request() {
  trace "Entering watchpub32request()..."

  local returncode
  local request=${1}
  local label=$(echo "${request}" | jq ".label" | tr -d '"')
  trace "[watchpub32request] label=${label}"
  local pub32=$(echo "${request}" | jq ".pub32" | tr -d '"')
  trace "[watchpub32request] pub32=${pub32}"
  local path=$(echo "${request}" | jq ".path" | tr -d '"')
  trace "[watchpub32request] path=${path}"
  local nstart=$(echo "${request}" | jq ".nstart")
  trace "[watchpub32request] nstart=${nstart}"
  local cb0conf_url=$(echo "${request}" | jq ".unconfirmedCallbackURL" | tr -d '"')
  trace "[watchpub32request] cb0conf_url=${cb0conf_url}"
  local cb1conf_url=$(echo "${request}" | jq ".confirmedCallbackURL" | tr -d '"')
  trace "[watchpub32request] cb1conf_url=${cb1conf_url}"

  watchpub32 ${label} ${pub32} ${path} ${nstart} ${cb0conf_url} ${cb1conf_url}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

watchpub32() {
  trace "Entering watchpub32()..."

  local returncode
  local label=${1}
  trace "[watchpub32] label=${label}"
  local pub32=${2}
  trace "[watchpub32] pub32=${pub32}"
  local path=${3}
  trace "[watchpub32] path=${path}"
  local nstart=${4}
  trace "[watchpub32] nstart=${nstart}"
  local last_n=$((${nstart}+${XPUB_DERIVATION_GAP}))
  trace "[watchpub32] last_n=${last_n}"
  local cb0conf_url=${5}
  trace "[watchpub32] cb0conf_url=${cb0conf_url}"
  local cb1conf_url=${6}
  trace "[watchpub32] cb1conf_url=${cb1conf_url}"

  # upto_n is used when extending the watching window
  local upto_n=${7}
  trace "[watchpub32] upto_n=${upto_n}"

  local id_inserted
  local result
  local error_msg
  local data

  # Derive with pycoin...
  # {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}
  if [ -n "${upto_n}" ]; then
    # If upto_n provided, then we create from nstart to upto_n (instead of + GAP)
    last_n=${upto_n}
  fi
  local subspath=$(echo -e $path | sed -En "s/n/${nstart}-${last_n}/p")
  trace "[watchpub32] subspath=${subspath}"
  local addresses
  addresses=$(derivepubpath "{\"pub32\":\"${pub32}\",\"path\":\"${subspath}\"}")
  returncode=$?
  trace_rc ${returncode}
#  trace "[watchpub32] addresses=${addresses}"

  if [ "${returncode}" -eq 0 ]; then
#    result=$(create_wallet "${pub32}")
#    returncode=$?
#    trace_rc ${returncode}
#    trace "[watchpub32request] result=${result}"
    trace "[watchpub32] Skipping create_wallet"

    if [ "${returncode}" -eq 0 ]; then
      # Importmulti in Bitcoin Core...
      result=$(importmulti_rpc "${WATCHER_BTC_NODE_XPUB_WALLET}" "${pub32}" "${addresses}")
      returncode=$?
      trace_rc ${returncode}
      trace "[watchpub32] result=${result}"

      if [ "${returncode}" -eq 0 ]; then
        if [ -n "${upto_n}" ]; then
          # Update existing row, we are extending the watching window
          sql "UPDATE watching_by_pub32 set last_imported_n=${upto_n} WHERE pub32=\"${pub32}\""
        else
          # Insert in our DB...
          sql "INSERT OR REPLACE INTO watching_by_pub32 (pub32, label, derivation_path, watching, callback0conf, callback1conf, last_imported_n) VALUES (\"${pub32}\", \"${label}\", \"${path}\", 1, \"${cb0conf_url}\", \"${cb1conf_url}\", ${last_n})"
        fi
        returncode=$?
        trace_rc ${returncode}

        if [ "${returncode}" -eq 0 ]; then
          id_inserted=$(sql "SELECT id FROM watching_by_pub32 WHERE label='${label}'")
          trace "[watchpub32] id_inserted: ${id_inserted}"

          addresses=$(echo ${addresses} | jq ".addresses[].address")
          insert_watches "${addresses}" "${cb0conf_url}" "${cb1conf_url}" ${id_inserted} ${nstart}
        else
          error_msg="Can't insert xpub watcher in DB"
        fi
      else
        error_msg="Can't import addresses"
      fi
    else
      error_msg="Can't create wallet"
    fi
  else
    error_msg="Can't derive addresses"
  fi

  if [ -z "${error_msg}" ]; then
    data="{\"id\":\"${id_inserted}\",
    \"event\":\"watchxpub\",
    \"pub32\":\"${pub32}\",
    \"label\":\"${label}\",
    \"path\":\"${path}\",
    \"nstart\":\"${nstart}\",
    \"unconfirmedCallbackURL\":\"${cb0conf_url}\",
    \"confirmedCallbackURL\":\"${cb1conf_url}\"}"

    returncode=0
  else
    data="{\"error\":\"${error_msg}\",
    \"event\":\"watchxpub\",
    \"pub32\":\"${pub32}\",
    \"label\":\"${label}\",
    \"path\":\"${path}\",
    \"nstart\":\"${nstart}\",
    \"unconfirmedCallbackURL\":\"${cb0conf_url}\",
    \"confirmedCallbackURL\":\"${cb1conf_url}\"}"

    returncode=1
  fi
  trace "[watchpub32] responding=${data}"

  echo "${data}"

  return ${returncode}
}

insert_watches() {
  trace "Entering insert_watches()..."

  local addresses=${1}
  local callback0conf=${2}
  local callback1conf=${3}
  local xpub_id=${4}
  local nstart=${5}
  local inserted_values=""

  local IFS=$'\n'
  for address in ${addresses}
  do
    # (address, watching, callback0conf, callback1conf, imported, watching_by_pub32_id)
    if [ -n "${inserted_values}" ]; then
      inserted_values="${inserted_values},"
    fi
    inserted_values="${inserted_values}(${address}, 1, \"${callback0conf}\", \"${callback1conf}\", 1"
    if [ -n "${xpub_id}" ]; then
      inserted_values="${inserted_values}, ${xpub_id}, ${nstart}"
      nstart=$((${nstart} + 1))
    fi
    inserted_values="${inserted_values})"
  done
#  trace "[insert_watches] inserted_values=${inserted_values}"

  sql "INSERT OR REPLACE INTO watching (address, watching, callback0conf, callback1conf, imported, watching_by_pub32_id, pub32_index) VALUES ${inserted_values}"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

extend_watchers() {
  trace "Entering extend_watchers()..."

  local watching_by_pub32_id=${1}
  trace "[extend_watchers] watching_by_pub32_id=${watching_by_pub32_id}"
  local pub32_index=${2}
  trace "[extend_watchers] pub32_index=${pub32_index}"
  local upgrade_to_n=$((${pub32_index} + ${XPUB_DERIVATION_GAP}))
  trace "[extend_watchers] upgrade_to_n=${upgrade_to_n}"

  local last_imported_n
  local row
  row=$(sql "SELECT pub32, label, derivation_path, callback0conf, callback1conf, last_imported_n FROM watching_by_pub32 WHERE id=${watching_by_pub32_id} AND watching")
  returncode=$?
  trace_rc ${returncode}

  trace "[extend_watchers] row=${row}"
  local pub32=$(echo "${row}" | cut -d '|' -f1)
  trace "[extend_watchers] pub32=${pub32}"
  local label=$(echo "${row}" | cut -d '|' -f2)
  trace "[extend_watchers] label=${label}"
  local derivation_path=$(echo "${row}" | cut -d '|' -f3)
  trace "[extend_watchers] derivation_path=${derivation_path}"
  local callback0conf=$(echo "${row}" | cut -d '|' -f4)
  trace "[extend_watchers] callback0conf=${callback0conf}"
  local callback1conf=$(echo "${row}" | cut -d '|' -f5)
  trace "[extend_watchers] callback1conf=${callback1conf}"
  local last_imported_n=$(echo "${row}" | cut -d '|' -f6)
  trace "[extend_watchers] last_imported_n=${last_imported_n}"

  if [ "${last_imported_n}" -lt "${upgrade_to_n}" ]; then
    # We want to keep our gap between last tx and last n watched...
    # For example, if the last imported n is 155 and we just got a tx with pub32 index of 66,
    # we want to extend the watched addresses to 166 if our gap is 100 (default).
    trace "[extend_watchers] We have addresses to add to watchers!"

    watchpub32 ${label} ${pub32} ${derivation_path} $((${last_imported_n} + 1)) ${callback0conf} ${callback1conf} ${upgrade_to_n} > /dev/null
    returncode=$?
    trace_rc ${returncode}
  else
    trace "[extend_watchers] Nothing to add!"
  fi

  return ${returncode}
}

watchtxidrequest() {
  trace "Entering watchtxidrequest()..."

  local returncode
  local request=${1}
  trace "[watchtxidrequest] request=${request}"
  local txid=$(echo "${request}" | jq ".txid" | tr -d '"')
  trace "[watchtxidrequest] txid=${txid}"
  local cb1conf_url=$(echo "${request}" | jq ".confirmedCallbackURL" | tr -d '"')
  trace "[watchtxidrequest] cb1conf_url=${cb1conf_url}"
  local cbxconf_url=$(echo "${request}" | jq ".xconfCallbackURL" | tr -d '"')
  trace "[watchtxidrequest] cbxconf_url=${cbxconf_url}"
  local nbxconf=$(echo "${request}" | jq ".nbxconf")
  trace "[watchtxidrequest] nbxconf=${nbxconf}"
  local inserted
  local id_inserted
  local result
  trace "[watchtxidrequest] Watch request on txid (${txid}), cb 1-conf (${cb1conf_url}) and cb x-conf (${cbxconf_url}) on ${nbxconf} confirmations."

  sql "INSERT OR IGNORE INTO watching_by_txid (txid, watching, callback1conf, callbackxconf, nbxconf) VALUES (\"${txid}\", 1, \"${cb1conf_url}\", \"${cbxconf_url}\", ${nbxconf})"
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    inserted=1
    id_inserted=$(sql "SELECT id FROM watching_by_txid WHERE txid='${txid}'")
    trace "[watchtxidrequest] id_inserted: ${id_inserted}"
  else
    inserted=0
  fi

  local data="{\"id\":\"${id_inserted}\",
  \"event\":\"watchtxid\",
  \"inserted\":\"${inserted}\",
  \"txid\":\"${txid}\",
  \"confirmedCallbackURL\":\"${cb1conf_url}\",
  \"xconfCallbackURL\":\"${cbxconf_url}\",
  \"nbxconf\":${nbxconf}}"
  trace "[watchtxidrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}
