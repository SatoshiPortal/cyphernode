#!/bin/sh

. ./trace.sh
. ./elements_importaddress.sh
. ./sql.sh
. ./sendtoelementsnode.sh

elements_watchrequest() {
  trace "Entering elements_watchrequest()..."

  local returncode
  local request=${1}
  local address=$(echo "${request}" | jq -r ".address")
  local unblinded_address
  local assetid=$(echo "${request}" | jq ".assetId")
  local cb0conf_url=$(echo "${request}" | jq ".unconfirmedCallbackURL")
  local cb1conf_url=$(echo "${request}" | jq ".confirmedCallbackURL")
  local event_message=$(echo "${request}" | jq ".eventMessage")
  local imported
  local inserted
  local id_inserted
  local result
  trace "[elements_watchrequest] Watch request on address (\"${address}\"), assetId (${assetid}), cb 0-conf (${cb0conf_url}), cb 1-conf (${cb1conf_url}) with event_message=${event_message}"

  local isvalid
  isvalid=$(elements_validateaddress "${address}" | jq ".result.isvalid")
  if [ "${isvalid}" != "true" ]; then
    result="{
      \"result\":null,
      \"error\":{
      \"code\":-5,
      \"message\":\"Invalid address\",
      \"data\":{
      \"event\":\"watch\",
      \"address\":\"${address}\",
      \"assetId\":${assetid},
      \"unconfirmedCallbackURL\":${cb0conf_url},
      \"confirmedCallbackURL\":${cb1conf_url},
      \"eventMessage\":${event_message}}}}"
    trace "[elements_watchrequest] Invalid address"

    echo "${result}"

    return 1
  fi

  result=$(elements_importaddress_rpc ${address})
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    imported=1
  else
    imported=0
  fi

  # We need to get the corresponding unblinded address to work around the elements gettransaction bug with blinded addresses
  unblinded_address=$(elements_getaddressinfo "${address}" true | jq -r ".result.unconfidential")
  trace "[elements_watchrequest] unblinded_address=${unblinded_address}"

  sql "INSERT OR REPLACE INTO elements_watching (address, unblinded_address, watching, callback0conf, callback1conf, imported, event_message, watching_assetid) VALUES (\"${address}\", \"${unblinded_address}\", 1, ${cb0conf_url}, ${cb1conf_url}, ${imported}, ${event_message}, ${assetid})"
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    inserted=1
    id_inserted=$(sql "SELECT id FROM elements_watching WHERE address='${address}'")
    trace "[elements_watchrequest] id_inserted: ${id_inserted}"
  else
    inserted=0
  fi

  local data="{\"id\":\"${id_inserted}\",
  \"event\":\"elements_watch\",
  \"imported\":\"${imported}\",
  \"inserted\":\"${inserted}\",
  \"address\":\"${address}\",
  \"unblindedAddress\":\"${unblinded_address}\",
  \"assetId\":${assetid},
  \"unconfirmedCallbackURL\":${cb0conf_url},
  \"confirmedCallbackURL\":${cb1conf_url},
  \"eventMessage\":${event_message}}"
  trace "[elements_watchrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}

elements_watchpub32request() {
  trace "Entering elements_watchpub32request()..."

  local returncode
  local request=${1}
  local label=$(echo "${request}" | jq -r ".label")
  trace "[elements_watchpub32request] label=${label}"
  local pub32=$(echo "${request}" | jq -r ".pub32")
  trace "[elements_watchpub32request] pub32=${pub32}"
  local path=$(echo "${request}" | jq -r ".path")
  trace "[elements_watchpub32request] path=${path}"
  local nstart=$(echo "${request}" | jq ".nstart")
  trace "[elements_watchpub32request] nstart=${nstart}"
  local cb0conf_url=$(echo "${request}" | jq ".unconfirmedCallbackURL")
  local cb1conf_url=$(echo "${request}" | jq ".confirmedCallbackURL")
  trace "[elements_watchpub32request] cb1conf_url=${cb1conf_url}"

  elements_watchpub32 ${label} ${pub32} ${path} ${nstart} ${cb0conf_url} ${cb1conf_url}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

elements_watchpub32() {
  trace "Entering elements_watchpub32()..."

  local returncode
  local label=${1}
  trace "[elements_watchpub32] label=${label}"
  local pub32=${2}
  trace "[elements_watchpub32] pub32=${pub32}"
  local path=${3}
  trace "[elements_watchpub32] path=${path}"
  local nstart=${4}
  trace "[elements_watchpub32] nstart=${nstart}"
  local last_n=$((${nstart}+${XPUB_DERIVATION_GAP}))
  trace "[elements_watchpub32] last_n=${last_n}"
  local cb0conf_url=${5}
  trace "[elements_watchpub32] cb0conf_url=${cb0conf_url}"
  local cb1conf_url=${6}
  trace "[elements_watchpub32] cb1conf_url=${cb1conf_url}"

  # upto_n is used when extending the watching window
  local upto_n=${7}
  trace "[elements_watchpub32] upto_n=${upto_n}"

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
  trace "[elements_watchpub32] subspath=${subspath}"
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
    trace "[elements_watchpub32] Skipping create_wallet"

    if [ "${returncode}" -eq 0 ]; then
      # Importmulti in Bitcoin Core...
      result=$(elements_importmulti_rpc "${WATCHER_ELEMENTS_NODE_XPUB_WALLET}" "${pub32}" "${addresses}")
      returncode=$?
      trace_rc ${returncode}
      trace "[elements_watchpub32] result=${result}"

      if [ "${returncode}" -eq 0 ]; then
        if [ -n "${upto_n}" ]; then
          # Update existing row, we are extending the watching window
          sql "UPDATE elements_watching_by_pub32 SET last_imported_n=${upto_n} WHERE pub32=\"${pub32}\""
        else
          # Insert in our DB...
          sql "INSERT OR REPLACE INTO elements_watching_by_pub32 (pub32, label, derivation_path, watching, callback0conf, callback1conf, last_imported_n) VALUES (\"${pub32}\", \"${label}\", \"${path}\", 1, ${cb0conf_url}, ${cb1conf_url}, ${last_n})"
        fi
        returncode=$?
        trace_rc ${returncode}

        if [ "${returncode}" -eq 0 ]; then
          id_inserted=$(sql "SELECT id FROM elements_watching_by_pub32 WHERE label='${label}'")
          trace "[watchpub32] id_inserted: ${id_inserted}"

          addresses=$(echo ${addresses} | jq ".addresses[].address")
          elements_insert_watches "${addresses}" ${cb0conf_url} ${cb1conf_url} ${id_inserted} ${nstart}
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
    \"event\":\"elements_watchxpub\",
    \"pub32\":\"${pub32}\",
    \"label\":\"${label}\",
    \"path\":\"${path}\",
    \"nstart\":\"${nstart}\",
    \"unconfirmedCallbackURL\":${cb0conf_url},
    \"confirmedCallbackURL\":${cb1conf_url}}"

    returncode=0
  else
    data="{\"error\":\"${error_msg}\",
    \"event\":\"elements_watchxpub\",
    \"pub32\":\"${pub32}\",
    \"label\":\"${label}\",
    \"path\":\"${path}\",
    \"nstart\":\"${nstart}\",
    \"unconfirmedCallbackURL\":${cb0conf_url},
    \"confirmedCallbackURL\":${cb1conf_url}}"

    returncode=1
  fi
  trace "[elements_watchpub32] responding=${data}"

  echo "${data}"

  return ${returncode}
}

elements_insert_watches() {
  trace "Entering elements_insert_watches()..."

  local addresses=${1}
  local callback0conf=${2}
  local callback1conf=${3}
  local xpub_id=${4}
  local nstart=${5}
  local inserted_values=""
  local address
  local unblinded_address

  local IFS=$'\n'
  for address in ${addresses}
  do
    # We need to get the corresponding unblinded address to work around the elements gettransaction bug with blinded addresses
    unblinded_address=$(elements_getaddressinfo ${address} true | jq ".result.unconfidential")
    trace "[elements_insert_watches] unblinded_address=${unblinded_address}"

    # (address, watching, callback0conf, callback1conf, imported, watching_by_pub32_id)
    if [ -n "${inserted_values}" ]; then
      inserted_values="${inserted_values},"
    fi
    inserted_values="${inserted_values}(${address}, ${unblinded_address}, 1, ${callback0conf}, ${callback1conf}, 1"
    if [ -n "${xpub_id}" ]; then
      inserted_values="${inserted_values}, ${xpub_id}, ${nstart}"
      nstart=$((${nstart} + 1))
    fi
    inserted_values="${inserted_values})"
  done
#  trace "[insert_watches] inserted_values=${inserted_values}"

  sql "INSERT OR REPLACE INTO elements_watching (address, unblinded_address, watching, callback0conf, callback1conf, imported, watching_by_pub32_id, pub32_index) VALUES ${inserted_values}"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

elements_extend_watchers() {
  trace "Entering elements_extend_watchers()..."

  local watching_by_pub32_id=${1}
  trace "[elements_extend_watchers] watching_by_pub32_id=${watching_by_pub32_id}"
  local pub32_index=${2}
  trace "[elements_extend_watchers] pub32_index=${pub32_index}"
  local upgrade_to_n=$((${pub32_index} + ${XPUB_ELEMENTS_DERIVATION_GAP}))
  trace "[elements_extend_watchers] upgrade_to_n=${upgrade_to_n}"

  local last_imported_n
  local row
  row=$(sql "SELECT pub32, label, derivation_path, callback0conf, callback1conf, last_imported_n FROM elements_watching_by_pub32 WHERE id=${watching_by_pub32_id} AND watching")
  returncode=$?
  trace_rc ${returncode}

  trace "[elements_extend_watchers] row=${row}"
  local pub32=$(echo "${row}" | cut -d '|' -f1)
  trace "[elements_extend_watchers] pub32=${pub32}"
  local label=$(echo "${row}" | cut -d '|' -f2)
  trace "[elements_extend_watchers] label=${label}"
  local derivation_path=$(echo "${row}" | cut -d '|' -f3)
  trace "[elements_extend_watchers] derivation_path=${derivation_path}"
  local callback0conf=$(echo "${row}" | cut -d '|' -f4)
  trace "[elements_extend_watchers] callback0conf=${callback0conf}"
  local callback1conf=$(echo "${row}" | cut -d '|' -f5)
  trace "[elements_extend_watchers] callback1conf=${callback1conf}"
  local last_imported_n=$(echo "${row}" | cut -d '|' -f6)
  trace "[elements_extend_watchers] last_imported_n=${last_imported_n}"

  if [ "${last_imported_n}" -lt "${upgrade_to_n}" ]; then
    # We want to keep our gap between last tx and last n watched...
    # For example, if the last imported n is 155 and we just got a tx with pub32 index of 66,
    # we want to extend the watched addresses to 166 if our gap is 100 (default).
    trace "[elements_extend_watchers] We have addresses to add to watchers!"

    elements_watchpub32 ${label} ${pub32} ${derivation_path} $((${last_imported_n} + 1)) "${callback0conf}" "${callback1conf}" ${upgrade_to_n} > /dev/null
    returncode=$?
    trace_rc ${returncode}
  else
    trace "[elements_extend_watchers] Nothing to add!"
  fi

  return ${returncode}
}

elements_watchtxidrequest() {
  trace "Entering elements_watchtxidrequest()..."

  local returncode
  local request=${1}
  trace "[elements_watchtxidrequest] request=${request}"
  local txid=$(echo "${request}" | jq -r ".txid")
  trace "[elements_watchtxidrequest] txid=${txid}"
  local cb1conf_url=$(echo "${request}" | jq ".confirmedCallbackURL")
  trace "[elements_watchtxidrequest] cb1conf_url=${cb1conf_url}"
  local cbxconf_url=$(echo "${request}" | jq ".xconfCallbackURL")
  trace "[elements_watchtxidrequest] cbxconf_url=${cbxconf_url}"
  local nbxconf=$(echo "${request}" | jq ".nbxconf")
  trace "[elements_watchtxidrequest] nbxconf=${nbxconf}"
  local inserted
  local id_inserted
  local result
  trace "[elements_watchtxidrequest] Watch request on txid (${txid}), cb 1-conf (${cb1conf_url}) and cb x-conf (${cbxconf_url}) on ${nbxconf} confirmations."

  sql "INSERT OR IGNORE INTO elements_watching_by_txid (txid, watching, callback1conf, callbackxconf, nbxconf) VALUES (\"${txid}\", 1, ${cb1conf_url}, ${cbxconf_url}, ${nbxconf})"
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    inserted=1
    id_inserted=$(sql "SELECT id FROM elements_watching_by_txid WHERE txid='${txid}'")
    trace "[elements_watchtxidrequest] id_inserted: ${id_inserted}"
  else
    inserted=0
  fi

  local data="{\"id\":\"${id_inserted}\",
  \"event\":\"elements_watchtxid\",
  \"inserted\":\"${inserted}\",
  \"txid\":\"${txid}\",
  \"confirmedCallbackURL\":${cb1conf_url,
  \"xconfCallbackURL\":${cbxconf_url},
  \"nbxconf\":${nbxconf}}"
  trace "[elements_watchtxidrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}
