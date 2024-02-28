#!/bin/sh

. ./trace.sh
. ./elements_importaddress.sh
. ./sql.sh
. ./sendtoelementsnode.sh

elements_watchrequest() {
  trace "Entering elements_watchrequest()..."

  local returncode
  local request=${1}
  local address address_pg
  address=$(echo "${request}" | jq -re ".address")
  if [ "$?" -ne "0" ]; then
    # address not found or null
    result='{"result":null,'\
'"error":{'\
'"code":-5,'\
'"message":"address required"}}'
    trace "[elements_watchrequest] address required"
    trace "[elements_watchrequest] responding=${result}"

    echo "${result}"

    return 1
  else
    address_pg="'${address}'"
  fi

  local unblinded_address unblinded_address_pg

  local assetid assetid_pg assetid_json
  assetid=$(echo "${request}" | jq -re ".assetId")
  if [ "$?" -ne "0" ]; then
    # assetId not found or null
    assetid_json="null"
    assetid_pg="null"
  else
    assetid_json="\"${assetid}\""
    assetid_pg="'${assetid}'"
  fi

  local cb0conf_url cb0conf_url_pg cb0conf_url_pg_where cb0conf_url_json
  cb0conf_url=$(echo "${request}" | jq -re ".unconfirmedCallbackURL")
  if [ "$?" -ne "0" ]; then
    # unconfirmedCallbackURL not found or null
    cb0conf_url_json="null"
    cb0conf_url_pg="null"
    cb0conf_url_pg_where=" IS NULL"
  else
    cb0conf_url_json="\"${cb0conf_url}\""
    cb0conf_url_pg="'${cb0conf_url}'"
    cb0conf_url_pg_where="=${cb0conf_url_pg}"
  fi

  local cb1conf_url cb1conf_url_pg cb1conf_url_pg_where cb1conf_url_json
  cb1conf_url=$(echo "${request}" | jq -re ".confirmedCallbackURL")
  if [ "$?" -ne "0" ]; then
    # confirmedCallbackURL not found or null
    cb1conf_url_json="null"
    cb1conf_url_pg="null"
    cb1conf_url_pg_where=" IS NULL"
  else
    cb1conf_url_json="\"${cb1conf_url}\""
    cb1conf_url_pg="'${cb1conf_url}'"
    cb1conf_url_pg_where="=${cb1conf_url_pg}"
  fi

  local event_message event_message_pg event_message_json
  event_message=$(echo "${request}" | jq -re ".eventMessage")
  if [ "$?" -ne "0" ]; then
    # eventMessage not found or null
    event_message_json="null"
    event_message_pg="null"
  else
    event_message_json="\"${event_message}\""
    event_message_pg="'${event_message}'"
  fi

  local label label_pg label_json
  label=$(echo "${request}" | jq -re ".label")
  if [ "$?" -ne "0" ]; then
    # label not found or null
    label_json="null"
    label_pg="null"
  else
    label_json="\"${label}\""
    label_pg="'${label}'"
  fi

  local imported
  local inserted
  local id_inserted
  local result
  trace "[elements_watchrequest] Watch request on address (${address}), assetId (${assetid_json}), cb 0-conf (${cb0conf_url_json}), cb 1-conf (${cb1conf_url_json}) with event_message=${event_message_json} and label=${label_json}"

  local isvalid
  isvalid=$(elements_validateaddress "${address}" | jq ".result.isvalid")
  if [ "${isvalid}" != "true" ]; then
    result='{'\
'"result":null,'\
'"error":{'\
'"code":-5,'\
'"message":"Invalid address",'\
'"data":{'\
'"event":"elements_watch",'\
'"address":'"${address}"','\
'"assetId":'${assetid_json}','\
'"unconfirmedCallbackURL":'${cb0conf_url_json}','\
'"confirmedCallbackURL":'${cb1conf_url_json}','\
'"label":'${label_json}','\
'"eventMessage":'${event_message_json}'}}}'
    trace "[elements_watchrequest] Invalid address"
    trace "[elements_watchrequest] responding=${result}"

    echo "${result}"

    return 1
  fi

  result=$(elements_importaddress_rpc "${address}" "${label}")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    imported=true
  else
    imported=false
  fi

  # We need to get the corresponding unblinded address to work around the elements gettransaction bug with blinded addresses
  unblinded_address=$(elements_getaddressinfo "${address}" true | jq -r ".result.unconfidential")
  unblinded_address_pg="'${unblinded_address}'"
  trace "[elements_watchrequest] unblinded_address=${unblinded_address}"

  id_inserted=$(sql "INSERT INTO elements_watching (address, unblinded_address, watching, callback0conf, callback1conf, imported, event_message, watching_assetid, label)"\
" VALUES (${address_pg}, ${unblinded_address_pg}, true, ${cb0conf_url_pg}, ${cb1conf_url_pg}, ${imported}, ${event_message_pg}, ${assetid_pg}, ${label_pg})"\
" ON CONFLICT (address, COALESCE(callback0conf, ''), COALESCE(callback1conf, '')) DO"\
" UPDATE SET watching=true, event_message=${event_message_pg}, calledback0conf=false, calledback1conf=false, watching_assetid=${assetid_pg}, label=${label_pg}"\
" RETURNING id" \
  "SELECT id FROM elements_watching WHERE address=${address_pg} AND callback0conf${cb0conf_url_pg_where} AND callback1conf${cb1conf_url_pg_where}")
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_watchrequest] id_inserted=${id_inserted}"

  if [ "${returncode}" -eq 0 ]; then
    inserted=true
    trace "[elements_watchrequest] id_inserted: ${id_inserted}"
  else
    inserted=false
  fi

  result='{"id":'${id_inserted}','\
'"event":"elements_watch",'\
'"imported":'${imported}','\
'"inserted":'${inserted}','\
'"address":"'${address}'",'\
'"unblindedAddress":"'${unblinded_address}'",'\
'"assetId":'${assetid_json}','\
'"unconfirmedCallbackURL":'${cb0conf_url_json}','\
'"confirmedCallbackURL":'${cb1conf_url_json}','\
'"label":'${label_json}','\
'"eventMessage":'${event_message_json}'}'
  trace "[elements_watchrequest] responding=${result}"

  echo "${result}"

  return ${returncode}
}

elements_watchpub32request() {
  trace "Entering elements_watchpub32request()..."

  # BODY {"label":"4421","pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/n","nstart":0,"unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}

  # Required:
  # - "label"
  # - "pub32"
  # - "path"
  # - "nstart"

  local returncode
  local request=${1}
  local label=$(echo "${request}" | jq -er ".label")
  if [ "$?" -ne "0" ]; then
    # label not found or null
    trace "[elements_watchpub32request] label required"
    echo '{"error":"label required","event":"elements_watchxpub"}'

    return 1
  fi
  trace "[elements_watchpub32request] label=${label}"
  local pub32=$(echo "${request}" | jq -er ".pub32")
  if [ "$?" -ne "0" ]; then
    # pub32 not found or null
    trace "[elements_watchpub32request] pub32 required"
    echo '{"error":"pub32 required","event":"elements_watchxpub"}'

    return 1
  fi
  trace "[elements_watchpub32request] pub32=${pub32}"
  local path=$(echo "${request}" | jq -er ".path")
  if [ "$?" -ne "0" ]; then
    # path not found or null
    trace "[elements_watchpub32request] path required"
    echo '{"error":"path required","event":"elements_watchxpub"}'

    return 1
  fi
  trace "[elements_watchpub32request] path=${path}"
  local nstart=$(echo "${request}" | jq -er ".nstart")
  if [ "$?" -ne "0" ]; then
    # nstart not found or null
    trace "[elements_watchpub32request] nstart required"
    echo '{"error":"nstart required","event":"elements_watchxpub"}'

    return 1
  fi
  trace "[elements_watchpub32request] nstart=${nstart}"

  local cb0conf_url=$(echo "${request}" | jq -r ".unconfirmedCallbackURL // empty")
  trace "[elements_watchpub32request] cb0conf_url=${cb0conf_url}"
  local cb1conf_url=$(echo "${request}" | jq -r ".confirmedCallbackURL // empty")
  trace "[elements_watchpub32request] cb1conf_url=${cb1conf_url}"

  elements_watchpub32 "${label}" "${pub32}" "${path}" "${nstart}" "${cb0conf_url}" "${cb1conf_url}"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

elements_watchpub32() {
  trace "Entering elements_watchpub32()..."

  # Expecting args without quotes
  # label, pub32, path and nstart are required
  # When cb0conf_url and cb1conf_url are empty, means null

  local returncode
  local label=${1}
  local label_pg="'${label}'"
  trace "[elements_watchpub32] label=${label}, label_pg=${label_pg}"
  local pub32=${2}
  local pub32_pg="'${pub32}'"
  trace "[elements_watchpub32] pub32=${pub32}, pub32_pg=${pub32_pg}"
  local path=${3}
  local path_pg="'${path}'"
  trace "[elements_watchpub32] path=${path}, path_pg=${path_pg}"
  local nstart=${4}
  trace "[elements_watchpub32] nstart=${nstart}"
  local last_n=$((${nstart}+${XPUB_ELEMENTS_DERIVATION_GAP}))
  trace "[elements_watchpub32] last_n=${last_n}"
  local cb0conf_url=${5}
  local cb0conf_url_pg cb0conf_url_json
  if [ -z "${cb0conf_url}" ]; then
    # Empty url
    cb0conf_url_json="null"
    cb0conf_url_pg="null"
  else
    cb0conf_url_json="\"${cb0conf_url}\""
    cb0conf_url_pg="'${cb0conf_url}'"
  fi
  trace "[elements_watchpub32] cb0conf_url=${cb0conf_url}, cb0conf_url_pg=${cb0conf_url_pg}"
  local cb1conf_url=${6}
  local cb1conf_url_pg cb1conf_url_json
  if [ -z "${cb1conf_url}" ]; then
    # Empty url
    cb1conf_url_json="null"
    cb1conf_url_pg="null"
  else
    cb1conf_url_json="\"${cb1conf_url}\""
    cb1conf_url_pg="'${cb1conf_url}'"
  fi
  trace "[elements_watchpub32] cb1conf_url=${cb1conf_url}, cb1conf_url_pg=${cb1conf_url_pg}"

  # upto_n is used when extending the watching window
  # If this is supplied, it means we will not INSERT into elements_watching_by_pub32, just add
  # corresponding rows into elements_watching
  local upto_n=${7}
  trace "[elements_watchpub32] upto_n=${upto_n}"

  local id_inserted
  local result
  local error_msg
  local data

  # Derive with elementsd...
  # {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}
  if [ -n "${upto_n}" ]; then
    # If upto_n provided, then we create from nstart to upto_n (instead of + GAP)
    last_n=${upto_n}
  else
    # If upto_n is not provided, it means it's a new elements_watching_by_pub32 to insert,
    # so let's make sure the label is not already in the table since label must
    # be unique... but the key driver is pub32.
    local row
    row=$(sql "SELECT id, pub32, derivation_path, callback0conf, callback1conf, last_imported_n, watching, inserted_ts FROM elements_watching_by_pub32 WHERE label=${label_pg}")
    returncode=$?
    trace_rc ${returncode}

    if [ ${#row} -ne 0 ]; then
      trace "[elements_watchpub32] This label already exists in elements_watching_by_pub32, must be unique."
      error_msg="This label already exists in elements_watching_by_pub32, must be unique."
    fi
  fi

  if [ -z "${error_msg}" ]; then
    local subspath=$(echo -e $path | sed -En "s/n/${nstart}-${last_n}/p")
    trace "[elements_watchpub32] subspath=${subspath}"
    local addresses
    addresses=$(elements_derivepubpath '{"pub32":"'${pub32}'","path":"'${subspath}'"}')
    returncode=$?
    trace_rc ${returncode}
  #  trace "[elements_watchpub32] addresses=${addresses}"

    if [ "${returncode}" -eq 0 ]; then
  #    result=$(create_wallet "${pub32}")
  #    returncode=$?
  #    trace_rc ${returncode}
  #    trace "[watchpub32request] result=${result}"
      trace "[elements_watchpub32] Skipping elements_create_wallet"

      if [ "${returncode}" -eq 0 ]; then
        # Importmulti in Elements Core...
        result=$(elements_importmulti_rpc "${WATCHER_ELEMENTS_NODE_XPUB_WALLET}" "${pub32}" "${addresses}")
        returncode=$?
        trace_rc ${returncode}
        trace "[elements_watchpub32] result=${result}"

        if [ "${returncode}" -eq 0 ]; then
          if [ -n "${upto_n}" ]; then
            # Update existing row, we are extending the watching window
            id_inserted=$(sql "UPDATE elements_watching_by_pub32 set last_imported_n=${upto_n} WHERE pub32=${pub32_pg} RETURNING id")
            returncode=$?
            trace_rc ${returncode}
          else
            # Insert in our DB...
            id_inserted=$(sql "INSERT INTO elements_watching_by_pub32 (pub32, label, derivation_path, watching, callback0conf, callback1conf, last_imported_n)"\
" VALUES (${pub32_pg}, ${label_pg}, ${path_pg}, true, ${cb0conf_url_pg}, ${cb1conf_url_pg}, ${last_n})"\
" ON CONFLICT (pub32) DO"\
" UPDATE SET watching=true, label=${label_pg}, callback0conf=${cb0conf_url_pg}, callback1conf=${cb1conf_url_pg}, derivation_path=${path_pg}, last_imported_n=${last_n}"\
" RETURNING id" \
            "SELECT id FROM elements_watching_by_pub32 WHERE pub32=${pub32_pg}")
            returncode=$?
            trace_rc ${returncode}
          fi

          if [ -n "${id_inserted}" ] && [ "${returncode}" -eq 0 ]; then
            trace "[elements_watchpub32] id_inserted: ${id_inserted}"

            addresses=$(echo ${addresses} | jq -r ".addresses[].address")
            elements_insert_watches "${addresses}" "${label}" "${cb0conf_url}" "${cb1conf_url}" "${id_inserted}" "${nstart}"
            returncode=$?
            trace_rc ${returncode}
            if [ "${returncode}" -ne 0 ]; then
              error_msg="Can't insert elements xpub watches in DB"
            fi
          else
            error_msg="Can't insert elements xpub watcher in DB"
          fi
        else
          error_msg="Can't import elements addresses"
        fi
      else
        error_msg="Can't create elements wallet"
      fi
    else
      error_msg="Can't derive elements addresses"
    fi
  fi

  if [ -z "${error_msg}" ]; then
    data='{"id":'${id_inserted}','\
'"event":"elements_watchxpub",'\
'"pub32":"'${pub32}'",'\
'"label":"'${label}'",'\
'"path":"'${path}'",'\
'"nstart":'${nstart}','\
'"unconfirmedCallbackURL":'${cb0conf_url_json}','\
'"confirmedCallbackURL":'${cb1conf_url_json}'}'

    returncode=0
  else
    data='{"error":"'${error_msg}'",'\
'"event":"elements_watchxpub",'\
'"pub32":"'${pub32}'",'\
'"label":"'${label}'",'\
'"path":"'${path}'",'\
'"nstart":'${nstart}','\
'"unconfirmedCallbackURL":'${cb0conf_url_json}','\
'"confirmedCallbackURL":'${cb1conf_url_json}'}'

    returncode=1
  fi
  trace "[elements_watchpub32] responding=${data}"

  echo "${data}"

  return ${returncode}
}

elements_insert_watches() {
  trace "Entering elements_insert_watches()..."

  # Expecting args without quotes
  # When callback0conf and callback1conf are empty, means null

  local addresses=${1}
  local label=${2}
  local label_pg
  if [ -z "${label}" ]; then
    # Empty url
    label_pg="null"
  else
    label_pg="'${label}'"
  fi
  local callback0conf=${3}
  local callback0conf_pg
  if [ -z "${callback0conf}" ]; then
    # Empty url
    callback0conf_pg="null"
  else
    callback0conf_pg="'${callback0conf}'"
  fi
  local callback1conf=${4}
  local callback1conf_pg
  if [ -z "${callback1conf}" ]; then
    # Empty url
    callback1conf_pg="null"
  else
    callback1conf_pg="'${callback1conf}'"
  fi
  local xpub_id=${5}
  local nstart=${6}
  local inserted_values
  local address
  local unblinded_address unblinded_address_pg

  local IFS="
"
  for address in ${addresses}
  do
    # We need to get the corresponding unblinded address to work around the elements gettransaction bug with blinded addresses
    unblinded_address=$(elements_getaddressinfo ${address} true | jq -r ".result.unconfidential")
    unblinded_address_pg="'${unblinded_address}'"
    trace "[elements_insert_watches] unblinded_address=${unblinded_address}"

    # (address, label, watching, callback0conf, callback1conf, imported, watching_by_pub32_id)
    if [ -n "${inserted_values}" ]; then
      inserted_values="${inserted_values},"
    fi
    inserted_values="${inserted_values}('${address}', ${unblinded_address_pg}, ${label_pg}, true, ${callback0conf_pg}, ${callback1conf_pg}, true, ${xpub_id}, ${nstart})"

    nstart=$((${nstart} + 1))
  done

  sql "INSERT INTO elements_watching (address, unblinded_address, label, watching, callback0conf, callback1conf, imported, elements_watching_by_pub32_id, pub32_index)"\
" VALUES ${inserted_values}"\
" ON CONFLICT (address, COALESCE(callback0conf, ''), COALESCE(callback1conf, '')) DO"\
" UPDATE SET watching=true, calledback0conf=false, calledback1conf=false, label=${label_pg}"
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

elements_extend_watchers() {
  trace "Entering elements_extend_watchers()..."

  # Expecting args without quotes

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

    elements_watchpub32 "${label}" "${pub32}" "${derivation_path}" "$((${last_imported_n} + 1))" "${callback0conf}" "${callback1conf}" "${upgrade_to_n}" > /dev/null
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
  local result
  local request=${1}
  trace "[elements_watchtxidrequest] request=${request}"
  local txid txid_pg txid_pg_where
  txid=$(echo "${request}" | jq -re ".txid")
  if [ "$?" -ne "0" ]; then
    # txid not found or null
    result='{"result":null,'\
'"error":{'\
'"code":-5,'\
'"message":"txid required"}}'
    trace "[elements_watchtxidrequest] txid required"
    trace "[elements_watchtxidrequest] responding=${result}"

    echo "${result}"

    return 1
  else
    txid_pg="'${address}'"
  fi
  trace "[elements_watchtxidrequest] txid=${txid}, txid_pg=${txid_pg}"

  local cb1conf_url cb1conf_url_pg cb1conf_url_pg_where cb1conf_url_json
  cb1conf_url=$(echo "${request}" | jq -re ".confirmedCallbackURL")
  if [ "$?" -ne "0" ]; then
    # cb1conf_url not found or null
    cb1conf_url_json="null"
    cb1conf_url_pg="null"
    cb1conf_url_pg_where=" IS NULL"
  else
    cb1conf_url_json="\"${cb1conf_url}\""
    cb1conf_url_pg="'${cb1conf_url}'"
    cb1conf_url_pg_where="=${cb1conf_url_pg}"
  fi
  trace "[elements_watchtxidrequest] cb1conf_url=${cb1conf_url}, cb1conf_url_pg=${cb1conf_url_pg}, cb1conf_url_pg_where=${cb1conf_url_pg_where}, cb1conf_url_json=${cb1conf_url_json}"

  local cbxconf_url cbxconf_url_pg cbxconf_url_pg_where
  cbxconf_url=$(echo "${request}" | jq -e ".xconfCallbackURL")
  if [ "$?" -ne "0" ]; then
    # cbxconf_url not found or null
    cbxconf_url_json="null"
    cbxconf_url_pg="null"
    cbxconf_url_pg_where=" IS NULL"
  else
    cbxconf_url_json="\"${cbxconf_url}\""
    cbxconf_url_pg="'${cbxconf_url}'"
    cbxconf_url_pg_where="=${cbxconf_url_pg}"
  fi
  trace "[elements_watchtxidrequest] cbxconf_url=${cbxconf_url}, cbxconf_url_pg=${cbxconf_url_pg}, cbxconf_url_pg_where=${cbxconf_url_pg_where}, cbxconf_url_json=${cbxconf_url_json}"

  local nbxconf=$(echo "${request}" | jq ".nbxconf")
  trace "[elements_watchtxidrequest] nbxconf=${nbxconf}"
  local cb1cond
  local cbxcond
  local inserted
  local id_inserted
  trace "[elements_watchtxidrequest] Watch request on txid (${txid}), cb 1-conf (${cb1conf_url}) and cb x-conf (${cbxconf_url}) on ${nbxconf} confirmations."

  id_inserted=$(sql "INSERT INTO elements_watching_by_txid (txid, watching, callback1conf, callbackxconf, nbxconf)"\
" VALUES (${txid_pg}, true, ${cb1conf_url_pg}, ${cbxconf_url_pg}, ${nbxconf})"\
" ON CONFLICT (txid, COALESCE(callback1conf, ''), COALESCE(callbackxconf, '')) DO"\
" UPDATE SET watching=true, nbxconf=${nbxconf}, calledback1conf=false, calledbackxconf=false"\
" RETURNING id" \
  "SELECT id FROM elements_watching_by_txid WHERE txid=${txid_pg} AND callback1conf${cb1conf_url_pg_where} AND callbackxconf${cbxconf_url_pg_where}")
  returncode=$?
  trace_rc ${returncode}

  if [ "${returncode}" -eq 0 ]; then
    inserted=true
    trace "[elements_watchtxidrequest] id_inserted: ${id_inserted}"
  else
    inserted=false
    id_inserted=null
  fi

  local data='{"id":'${id_inserted}','\
'"event":"elements_watchtxid",'\
'"inserted":'${inserted}','\
'"txid":"'${txid}'",'\
'"confirmedCallbackURL":'${cb1conf_url_json}','\
'"xconfCallbackURL":'${cbxconf_url_json}','\
'"nbxconf":'${nbxconf}'}'
  trace "[elements_watchtxidrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}
