#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./callbacks_job.sh
. ./sendtobitcoinnode.sh
. ./responsetoclient.sh
. ./computefees.sh
. ./watchrequest.sh

# Expecting 2 params
#
# 1: base64 encoded
# {
#  "amount": 0.00010000,
#  "confirmations": 1,
#  "blockhash": "3f81808e33b9d07a9a022e070dd790be079d0af157d35c7b05ef461e78a5b6fb",
#  "blockheight": 108,
#  "blockindex": 1,
#  "blocktime": 1655218274,
#  "txid": "e4a492e9d367bd1feaa6a4aab8cdda120f10d56abb1230e1b6146dc339d37cdf",
#  "walletconflicts": [
#  ],
#  "time": 1655216562,
#  "timereceived": 1655216562,
#  "bip125-replaceable": "no",
#  "details": [
#    {
#      "involvesWatchonly": true,
#      "address": "bcrt1q3zlnle9u90uxg6a267udga8zhmc5ppy5qn34fe",
#      "category": "receive",
#      "amount": 0.00010000,
#      "label": "watch_label22791",
#      "vout": 0
#    }
#  ],
#  "hex": "02000000000101086369f53e9f13ba6104b4efc0995f7ff0724a0b53eb8b49f5297387cdbc01460000000000fdffffff02102700000000000016001488bf3fe4bc2bf8646baad7b8d474e2bef1408494d83d052a01000000160014a826dbbef73081aca17d486b907d1a5e16219d8b0247304402206e20cb9611610597426d2580eec0899f90c7000c85af8dee7dabfda34b60724f02200124ce1a53426ee44fd8e49d87d4c2c49fe14077367df1a5b236dd17f4646d9f012102f86ca416271b87df55a5b007b183afbc0eaec26ca2b493ccd07eb5b0d331c2716b000000",
#  "decoded": {
#    "txid": "e4a492e9d367bd1feaa6a4aab8cdda120f10d56abb1230e1b6146dc339d37cdf",
#    "hash": "9a54a8d940ffec9c0d7e214f9bef6207e8dcd6a88cbc5f13776efdb0d1a81feb",
#    "version": 2,
#    "size": 222,
#    "vsize": 141,
#    "weight": 561,
#    "locktime": 107,
#    "vin": [
#      {
#        "txid": "4601bccd877329f5498beb530b4a72f07f5f99c0efb40461ba139f3ef5696308",
#        "vout": 0,
#        "scriptSig": {
#          "asm": "",
#          "hex": ""
#        },
#        "txinwitness": [
#          "304402206e20cb9611610597426d2580eec0899f90c7000c85af8dee7dabfda34b60724f02200124ce1a53426ee44fd8e49d87d4c2c49fe14077367df1a5b236dd17f4646d9f01",
#          "02f86ca416271b87df55a5b007b183afbc0eaec26ca2b493ccd07eb5b0d331c271"
#        ],
#        "sequence": 4294967293
#      }
#   ],
#    "vout": [
#      {
#        "value": 0.00010000,
#        "n": 0,
#        "scriptPubKey": {
#          "asm": "0 88bf3fe4bc2bf8646baad7b8d474e2bef1408494",
#          "hex": "001488bf3fe4bc2bf8646baad7b8d474e2bef1408494",
#          "address": "bcrt1q3zlnle9u90uxg6a267udga8zhmc5ppy5qn34fe",
#          "type": "witness_v0_keyhash"
#        }
#      },
#      {
#        "value": 49.99953880,
#        "n": 1,
#        "scriptPubKey": {
#          "asm": "0 a826dbbef73081aca17d486b907d1a5e16219d8b",
#          "hex": "0014a826dbbef73081aca17d486b907d1a5e16219d8b",
#          "address": "bcrt1q4qndh0hhxzq6egtafp4eqlg6tctzr8vtuy382f",
#          "type": "witness_v0_keyhash"
#        }
#      }
#    ]
#  }
#}
#

# 2: boolean bypass_callbacks (optional)
#
confirmation() {
  trace "[confirmation] Entering confirmation()..."

  local tx_details=$(echo "${1}" | base64 -d)
  local bypass_callbacks=${2}

  trace "[confirmation] tx_details=${tx_details}"
  trace "[confirmation] bypass_callbacks=${bypass_callbacks}"

  local txid=$(echo "$tx_details" | jq .txid | tr -d \")

  (
  flock --verbose -x 9 1>&2 

  local returncode
  local tx_details=$(echo "${1}" | base64 -d)
  local bypass_callbacks=${2}

  trace "[confirmation] tx_details=${tx_details}"
  trace "[confirmation] bypass_callbacks=${bypass_callbacks}"

  local returncode

  ########################################################################################################
  # First of all, let's make sure we're working on watched addresses...
  local address
  local addresseswhere
  local addresses=$(echo "${tx_details}" | jq -r ".details[].address")

  trace "[confirmation] addresses=${addresses}"

  local notfirst=false
  local IFS="
"
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
  local tx_nb_conf=$(echo "${tx_details}" | jq -r '.confirmations // 0')
  local tx_hash=$(echo "${tx_details}" | jq -r '.decoded.hash')

  # Sometimes raw tx are too long to be passed as paramater, so let's write
  # it to a temp file for it to be read by sqlite3 and then delete the file
  echo "${tx_details}" | jq -Mc '.decoded' > rawtx-${txid}-$$.blob

  if [ -z ${tx} ]; then
    # TX not found in our DB.
    # 0-conf or missed conf (managed or while spending) or spending an unconfirmed
    # (note: spending an unconfirmed TX must be avoided or we'll get here spending an unprocessed watching)

    # Let's first insert the tx in our DB

    local tx_ts_firstseen=$(echo "${tx_details}" | jq '.timereceived')
    local tx_amount=$(echo "${tx_details}" | jq '.amount')

    local tx_size=$(echo "${tx_details}" | jq '.decoded.size')
    local tx_vsize=$(echo "${tx_details}" | jq '.decoded.vsize')
    local tx_replaceable=$(echo "${tx_details}" | jq -r '."bip125-replaceable"')
    tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo "true" || echo "false")

    local fees=$(compute_fees "${txid}")
    trace "[confirmation] fees=${fees}"
    trace "[confirmation] tx_hash=${tx_hash}"

    # If we missed 0-conf...
    local tx_blockhash=null
    local tx_blockheight=null
    local tx_blocktime=null
    if [ "${tx_nb_conf}" -gt "0" ]; then
      trace "[confirmation] tx_nb_conf=${tx_nb_conf}"
      tx_blockhash="$(echo "${tx_details}" | jq -r '.blockhash')"
      tx_blockheight=$(echo "${tx_details}" | jq -r '.blockheight')
      tx_blockhash="'${tx_blockhash}'"
      tx_blocktime=$(echo "${tx_details}" | jq '.blocktime')
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

    local tx_blockhash=$(echo "${tx_details}" | jq -r '.blockhash')
    trace "[confirmation] tx_blockhash=${tx_blockhash}"
    if [ "${tx_blockhash}" = "null" ]; then
      trace "[confirmation] probably being called by executecallbacks without any confirmations since the last time we checked"
    else
      local tx_blockheight=$(echo "${tx_details}" | jq -r '.blockheight')
      local tx_blocktime=$(echo "${tx_details}" | jq '.blocktime')

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
    tx_vout_amount=$(echo "${tx_details}" | jq ".details | map(select(.address==\"${address}\"))[0] | .amount | fabs" | awk '{ printf "%.8f", $0 }')
    # In the case of us spending to a watched address, the address appears twice in the details,
    # once on the spend side (negative amount) and once on the receiving side (positive amount)
    tx_vout_n=$(echo "${tx_details}" | jq ".details | map(select(.address==\"${address}\"))[0] | .vout")

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
      extend_watchers "${watching_by_pub32_id}" "${pub32_index}"
    fi
    ########################################################################################################

    ########################################################################################################
    # Let's publish the event if needed
    event_message=$(echo "${row}" | cut -d '|' -f5)
    if [ -n "${event_message}" ]; then
      # There's an event message, let's publish it!

      trace "[confirmation] mosquitto_pub -h broker -t tx_confirmation -m \"{\"txid\":\"${txid}\",\"hash\":\"${tx_hash}\",\"address\":\"${address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}\""
      response=$(mosquitto_pub -h broker -t tx_confirmation -m "{\"txid\":\"${txid}\",\"hash\":\"${tx_hash}\",\"address\":\"${address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}")
      returncode=$?
      trace_rc ${returncode}
    fi
    ########################################################################################################

  done

  ) 9>./.confirmation.lock

  # There's a lock in callbacks, let's get out of the confirmation lock before entering another one
  # If this was called by missed_conf algo, we don't want to process all the callbacks now.  We wait
  # for next cron.
  if [ -z "${bypass_callbacks}" ]; then
    trace "[confirmation] Let's do the callbacks!"
    do_callbacks "${txid}"
  else
    trace "[confirmation] Skipping callbacks as requested"
  fi

  echo '{"result":"confirmed"}'

  return 0
}

case "${0}" in *confirmation.sh) confirmation "$@";; esac
