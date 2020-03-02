#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./elements_callbacks_job.sh
. ./sendtoelementsnode.sh
. ./responsetoclient.sh
. ./elements_blockchainrpc.sh

elements_confirmation_request() {
  # We are receiving a HTTP request, let's find the TXID from it

  trace "Entering elements_confirmation_request()..."

  local request=${1}
  local txid=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)

  elements_confirmation "${txid}"
  return $?
}

elements_confirmation() {
  (
  flock -x 201

  trace "Entering elements_confirmation()..."

  local returncode
  local txid=${1}
  local tx_details
  tx_details="$(elements_get_transaction ${txid} true)"
  returncode=$?
  trace_rc ${returncode}
  trace "[elements_confirmation] tx_details=${tx_details}"
  if [ "${returncode}" -ne "0" ]; then
    trace "[elements_confirmation] Transaction not in watcher, exiting."
    return 0
  fi
  ########################################################################################################
  # First of all, let's make sure we're working on watched addresses...
  local address
  local addresseswhere
  local addresses=$(echo "${tx_details}" | jq ".result.details[].address")

  local notfirst=false
  local IFS=$'\n'
  for address in ${addresses}
  do
    trace "[elements_confirmation] address=${address}"

    if ${notfirst}; then
      addresseswhere="${addresseswhere},${address}"
    else
      addresseswhere="${address}"
      notfirst=true
    fi
  done
  local rows=$(sql "SELECT id, address, unblinded_address, watching_by_pub32_id, pub32_index, event_message, watching_assetid FROM elements_watching WHERE watching AND (address IN (${addresseswhere}) OR unblinded_address IN (${addresseswhere}))")
  if [ ${#rows} -eq 0 ]; then
    trace "[elements_confirmation] No watched address in this tx!"
    return 0
  fi
  ########################################################################################################

  local tx=$(sql "SELECT id FROM elements_tx WHERE txid=\"${txid}\"")
  local id_inserted
  local tx_raw_details=$(elements_get_rawtransaction ${txid} true)
  local tx_nb_conf=$(echo "${tx_details}" | jq -r '.result.confirmations // 0')

  # Sometimes raw tx are too long to be passed as paramater, so let's write
  # it to a temp file for it to be read by sqlite3 and then delete the file
  echo "${tx_raw_details}" > conf-rawtx-${txid}.blob

  if [ -z ${tx} ]; then
    # TX not found in our DB.
    # 0-conf or missed conf (managed or while spending) or spending an unconfirmed
    # (note: spending an unconfirmed TX must be avoided or we'll get here spending an unprocessed watching)

    # Let's first insert the tx in our DB

    local tx_hash=$(echo "${tx_raw_details}" | jq '.result.hash')
    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.result.amount.bitcoin | fabs')

    local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
    local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq '.result."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo 1 || echo 0)

    # The fees in elements are unblinded
    local fees=$(echo "${tx_raw_details}" | jq '.result.vout[] | select(.scriptPubKey.type == "fee") | .value' | awk '{ printf "%.8f", $0 }')
    trace "[elements_confirmation] fees=${fees}"

    # If we missed 0-conf...
    local tx_blockhash=null
    local tx_blockheight=null
    local tx_blocktime=null
    if [ "${tx_nb_conf}" -gt "0" ]; then
      trace "[elements_confirmation] tx_nb_conf=${tx_nb_conf}"
      tx_blockhash=$(echo "${tx_details}" | jq '.result.blockhash')
      tx_blockheight=$(elements_get_block_info $(echo ${tx_blockhash} | tr -d '"') | jq '.result.height')
      tx_blocktime=$(echo "${tx_details}" | jq '.result.blocktime')
    fi

    sql "INSERT OR IGNORE INTO elements_tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, blockhash, blockheight, blocktime, raw_tx) VALUES (\"${txid}\", ${tx_hash}, ${tx_nb_conf}, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, ${tx_blockhash}, ${tx_blockheight}, ${tx_blocktime}, readfile('conf-rawtx-${txid}.blob'))"
    trace_rc $?

    id_inserted=$(sql "SELECT id FROM elements_tx WHERE txid='${txid}'")
    trace_rc $?

  else
    # TX found in our DB.
    # 1-conf or executecallbacks on an unconfirmed tx or spending watched address (in this case, we probably missed conf) or spending to a watched address (in this case, spend inserted the tx in the DB)

    local tx_blockhash=$(echo "${tx_details}" | jq '.result.blockhash')
    trace "[elements_confirmation] tx_blockhash=${tx_blockhash}"
    if [ "${tx_blockhash}" = "null" ]; then
      trace "[elements_confirmation] probably being called by executecallbacks without any confirmations since the last time we checked"
    else
      local tx_blockheight=$(elements_get_block_info $(echo "${tx_blockhash}" | tr -d '"') | jq '.result.height')
      local tx_blocktime=$(echo "${tx_details}" | jq '.result.blocktime')

      sql "UPDATE elements_tx SET
        confirmations=${tx_nb_conf},
        blockhash=${tx_blockhash},
        blockheight=${tx_blockheight},
        blocktime=${tx_blocktime},
        raw_tx=readfile('conf-rawtx-${txid}.blob')
        WHERE txid=\"${txid}\""
      trace_rc $?
    fi
    id_inserted=${tx}
  fi
  # Delete the temp file containing the raw tx (see above)
  rm conf-rawtx-${txid}.blob

  ########################################################################################################

  local event_message
  local watching_id
  local unblinded_address

  # Let's see if we need to insert tx in the join table
  tx=$(sql "SELECT elements_tx_id FROM elements_watching_tx WHERE elements_tx_id=${id_inserted}")

  for row in ${rows}
  do

    address=$(echo "${row}" | cut -d '|' -f2)
    unblinded_address=$(echo "${row}" | cut -d '|' -f3)
    tx_vout_amount=$(echo "${tx_details}" | jq ".result.details | map(select(.address==\"${unblinded_address}\"))[0] | .amount | fabs" | awk '{ printf "%.8f", $0 }')
    # In the case of us spending to a watched address, the address appears twice in the details,
    # once on the spend side (negative amount) and once on the receiving side (positive amount)
    tx_vout_n=$(echo "${tx_details}" | jq ".result.details | map(select(.address==\"${unblinded_address}\"))[0] | .vout")
    tx_vout_assetid=$(echo "${tx_details}" | jq ".result.details | map(select(.address==\"${unblinded_address}\"))[0] | .asset")

    ########################################################################################################
    # Let's now insert in the join table if not already done
    if [ -z "${tx}" ]; then
      trace "[elements_confirmation] For this tx, there's no watching_tx row, let's create it"

      # If the tx is batched and pays multiple watched addresses, we have to insert
      # those additional addresses in watching_tx!
      watching_id=$(echo "${row}" | cut -d '|' -f1)
      sql "INSERT OR IGNORE INTO elements_watching_tx (elements_watching_id, elements_tx_id, vout, amount, assetid) VALUES (${watching_id}, ${id_inserted}, ${tx_vout_n}, ${tx_vout_amount}, ${tx_vout_assetid})"
      trace_rc $?
    else
      trace "[elements_confirmation] For this tx, there's already watching_tx rows"
    fi
    ########################################################################################################

    ########################################################################################################
    # Let's now grow the watch window in the case of a xpub watcher...
    watching_by_pub32_id=$(echo "${row}" | cut -d '|' -f4)
    if [ -n "${watching_by_pub32_id}" ]; then
      trace "[elements_confirmation] Let's now grow the watch window in the case of a xpub watcher"

      pub32_index=$(echo "${row}" | cut -d '|' -f5)
      elements_extend_watchers ${watching_by_pub32_id} ${pub32_index}
    fi
    ########################################################################################################

    ########################################################################################################
    # Let's publish the event if needed
    event_message=$(echo "${row}" | cut -d '|' -f6)
    watching_assetid=$(echo "${row}" | cut -d '|' -f7)
    if [ -n "${event_message}" ]; then
      # There's an event message, let's publish it!

      trace "[elements_confirmation] mosquitto_pub -h broker -t elements_tx_confirmation -m \"{\"txid\":\"${txid}\",\"address\":\"${address}\",\"unblindedAddress\":\"${unblinded_address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"watchingAssetId\":\"${watching_assetid}\",\"assetId\":${tx_vout_assetid},\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}\""
      response=$(mosquitto_pub -h broker -t elements_tx_confirmation -m "{\"txid\":\"${txid}\",\"address\":\"${address}\",\"unblindedAddress\":\"${unblinded_address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"watchingAssetId\":\"${watching_assetid}\",\"assetId\":${tx_vout_assetid},\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}")
      returncode=$?
      trace_rc ${returncode}
    fi
    ########################################################################################################

  done

  ) 201>./.elements_confirmation.lock

  # There's a lock in callbacks, let's get out of the confirmation lock before entering another one
  elements_do_callbacks
  echo '{"result":"confirmed"}'

  return 0
}
