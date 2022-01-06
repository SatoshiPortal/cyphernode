#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./callbacks_job.sh
. ./sendtobitcoinnode.sh
. ./responsetoclient.sh
. ./computefees.sh
. ./blockchainrpc.sh

confirmation_request()
{
  # We are receiving a HTTP request, let's find the TXID from it

  trace "Entering confirmation_request()..."

  local request=${1}
  local txid=$(echo "${request}" | cut -d ' ' -f2 | cut -d '/' -f3)

  confirmation "${txid}"
  return $?
}

confirmation() {
  (
  flock -x 201

  trace "Entering confirmation()..."

  local returncode
  local txid=${1}
  local bypass_callbacks=${2}
  trace "[confirmation] bypass_callbacks=${bypass_callbacks}"
  local tx_details
  tx_details="$(get_transaction ${txid})"
  returncode=$?
  trace_rc ${returncode}
  trace "[confirmation] tx_details=${tx_details}"
  if [ "${returncode}" -ne "0" ]; then
    trace "[confirmation] Transaction not in watcher, exiting."
    return 0
  fi
  ########################################################################################################
  # First of all, let's make sure we're working on watched addresses...
  local address
  local addresseswhere
  local addresses=$(echo "${tx_details}" | jq -r ".result.details[].address")

  local notfirst=false
  local IFS=$'\n'
  for address in ${addresses}
  do
    trace "[confirmation] address=${address}"

    if ${notfirst}; then
      addresseswhere="${addresseswhere},'${address}'"
    else
      addresseswhere="'${address}'"
      notfirst=true
    fi
  done
  local rows=$(sql "SELECT id, address, watching_by_pub32_id, pub32_index, event_message FROM watching WHERE address IN (${addresseswhere}) AND watching")
  if [ ${#rows} -eq 0 ]; then
    trace "[confirmation] No watched address in this tx!"
    return 0
  fi
  ########################################################################################################

  local tx=$(sql "SELECT id FROM tx WHERE txid='${txid}'")
  local id_inserted
  local tx_raw_details=$(get_rawtransaction ${txid} | tr -d '\n')
  local tx_nb_conf=$(echo "${tx_details}" | jq -r '.result.confirmations // 0')
  local tx_hash=$(echo "${tx_raw_details}" | jq -r '.result.hash')

  # Sometimes raw tx are too long to be passed as paramater, so let's write
  # it to a temp file for it to be read by sqlite3 and then delete the file
  echo "${tx_raw_details}" > rawtx-${txid}-$$.blob

  if [ -z ${tx} ]; then
    # TX not found in our DB.
    # 0-conf or missed conf (managed or while spending) or spending an unconfirmed
    # (note: spending an unconfirmed TX must be avoided or we'll get here spending an unprocessed watching)

    # Let's first insert the tx in our DB

    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.result.amount')

    local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
    local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq -r '.result."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo "true" || echo "false")

    local fees=$(compute_fees "${txid}")
    trace "[confirmation] fees=${fees}"

    # If we missed 0-conf...
    local tx_blockhash=null
    local tx_blockheight=null
    local tx_blocktime=null
    if [ "${tx_nb_conf}" -gt "0" ]; then
      trace "[confirmation] tx_nb_conf=${tx_nb_conf}"
      tx_blockhash="$(echo "${tx_details}" | jq -r '.result.blockhash')"
      tx_blockheight=$(get_block_info ${tx_blockhash} | jq '.result.height')
      tx_blockhash="'${tx_blockhash}'"
      tx_blocktime=$(echo "${tx_details}" | jq '.result.blocktime')
    fi

    id_inserted=$(sql "INSERT INTO tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, blockhash, blockheight, blocktime)"\
" VALUES ('${txid}', '${tx_hash}', ${tx_nb_conf}, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, ${tx_blockhash}, ${tx_blockheight}, ${tx_blocktime})"\
" ON CONFLICT (txid) DO"\
" UPDATE SET blockhash=${tx_blockhash}, blockheight=${tx_blockheight}, blocktime=${tx_blocktime}, confirmations=${tx_nb_conf}"\
" RETURNING id" \
    "SELECT id FROM tx WHERE txid='${txid}'")
    trace_rc $?

  else
    # TX found in our DB.
    # 1-conf or executecallbacks on an unconfirmed tx or spending watched address (in this case, we probably missed conf) or spending to a watched address (in this case, spend inserted the tx in the DB)

    local tx_blockhash=$(echo "${tx_details}" | jq -r '.result.blockhash')
    trace "[confirmation] tx_blockhash=${tx_blockhash}"
    if [ "${tx_blockhash}" = "null" ]; then
      trace "[confirmation] probably being called by executecallbacks without any confirmations since the last time we checked"
    else
      local tx_blockheight=$(get_block_info "${tx_blockhash}" | jq '.result.height')
      local tx_blocktime=$(echo "${tx_details}" | jq '.result.blocktime')

      sql "UPDATE tx SET confirmations=${tx_nb_conf}, blockhash='${tx_blockhash}', blockheight=${tx_blockheight}, blocktime=${tx_blocktime} WHERE txid='${txid}'"
      trace_rc $?
    fi
    id_inserted=${tx}
  fi
  # Delete the temp file containing the raw tx (see above)
  rm rawtx-${txid}-$$.blob

  ########################################################################################################

  local event_message
  local watching_id

  # Let's see if we need to insert tx in the join table
  tx=$(sql "SELECT tx_id FROM watching_tx WHERE tx_id=${id_inserted}")

  for row in ${rows}
  do

    address=$(echo "${row}" | cut -d '|' -f2)
    tx_vout_amount=$(echo "${tx_details}" | jq ".result.details | map(select(.address==\"${address}\"))[0] | .amount | fabs" | awk '{ printf "%.8f", $0 }')
    # In the case of us spending to a watched address, the address appears twice in the details,
    # once on the spend side (negative amount) and once on the receiving side (positive amount)
    tx_vout_n=$(echo "${tx_details}" | jq ".result.details | map(select(.address==\"${address}\"))[0] | .vout")

    ########################################################################################################
    # Let's now insert in the join table if not already done
    if [ -z "${tx}" ]; then
      trace "[confirmation] For this tx, there's no watching_tx row, let's create it"

      # If the tx is batched and pays multiple watched addresses, we have to insert
      # those additional addresses in watching_tx!
      watching_id=$(echo "${row}" | cut -d '|' -f1)
      sql "INSERT INTO watching_tx (watching_id, tx_id, vout, amount) VALUES (${watching_id}, ${id_inserted}, ${tx_vout_n}, ${tx_vout_amount})"\
" ON CONFLICT DO NOTHING"
      trace_rc $?
    else
      trace "[confirmation] For this tx, there's already watching_tx rows"
    fi
    ########################################################################################################

    ########################################################################################################
    # Let's now grow the watch window in the case of a xpub watcher...
    watching_by_pub32_id=$(echo "${row}" | cut -d '|' -f3)
    if [ -n "${watching_by_pub32_id}" ]; then
      trace "[confirmation] Let's now grow the watch window in the case of a xpub watcher"

      pub32_index=$(echo "${row}" | cut -d '|' -f4)
      extend_watchers ${watching_by_pub32_id} ${pub32_index}
    fi
    ########################################################################################################

    ########################################################################################################
    # Let's publish the event if needed
    event_message=$(echo "${row}" | cut -d '|' -f5)
    if [ -n "${event_message}" ]; then
      # There's an event message, let's publish it!

      trace "[confirmation] mosquitto_pub -h broker -t tx_confirmation -m \"{\"txid\":\"${txid}\",\"hash\":${tx_hash},\"address\":\"${address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}\""
      response=$(mosquitto_pub -h broker -t tx_confirmation -m "{\"txid\":\"${txid}\",\"hash\":${tx_hash},\"address\":\"${address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}")
      returncode=$?
      trace_rc ${returncode}
    fi
    ########################################################################################################

  done

  ) 201>./.confirmation.lock

  # There's a lock in callbacks, let's get out of the confirmation lock before entering another one
  # If this was called by missed_conf algo, we don't want to process all the callbacks now.  We wait
  # for next cron.
  if [ -z "${bypass_callbacks}" ]; then
    trace "[confirmation] Let's do the callbacks!"
    do_callbacks "${txid}"
  fi

  echo '{"result":"confirmed"}'

  return 0
}

case "${0}" in *confirmation.sh) confirmation $@;; esac
