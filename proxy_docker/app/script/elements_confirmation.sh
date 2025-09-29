#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./elements_callbacks_job.sh
. ./sendtoelementsnode.sh
. ./responsetoclient.sh
. ./elements_watchrequest.sh

# Expecting 2 params
#
# 1: base64 encoded
# {
#   "amount": {
#     "bitcoin": 0
#   },
#   "fee": {
#     "bitcoin": -2.58e-06
#   },
#   "confirmations": 2,
#   "blockhash": "55f53ab6855a9c987eac983f5a8dec5c188a361728e11fbe79ca6cc928c60f8e",
#   "blockheight": 108,
#   "blockindex": 1,
#   "blocktime": 1737058041,
#   "txid": "f91fd39733dcdcc53a4ac465829f22d69896a76f46b67b0cd301b295e1d428d0",
#   "walletconflicts": [],
#   "time": 1737058004,
#   "timereceived": 1737058004,
#   "bip125-replaceable": "no",
#   "details": [
#     {
#       "address": "ert1qghm3sfhv5cgrtv7nklfgdrxmkpm8n7jf7pzxp5",
#       "category": "send",
#       "amount": -1e-05,
#       "amountblinder": "8ab160012cf03c1bde18680e2bdcbee75a7da887034f06468225df15f265b96d",
#       "asset": "b2e15d0d7a0c94e4e2ce0fe6e8691b9e451377f6e46e8045a86f7c4b5d4f0f23",
#       "assetblinder": "9dbd6ae735a124fe0cf3a98499c0c9aeaa002da00f40964b4e27c4dda661e2e6",
#       "label": "missed0conftest",
#       "vout": 0,
#       "fee": 2.58e-06,
#       "abandoned": false
#     },
#     {
#       "address": "ert1qghm3sfhv5cgrtv7nklfgdrxmkpm8n7jf7pzxp5",
#       "category": "receive",
#       "amount": 1e-05,
#       "amountblinder": "8ab160012cf03c1bde18680e2bdcbee75a7da887034f06468225df15f265b96d",
#       "asset": "b2e15d0d7a0c94e4e2ce0fe6e8691b9e451377f6e46e8045a86f7c4b5d4f0f23",
#       "assetblinder": "9dbd6ae735a124fe0cf3a98499c0c9aeaa002da00f40964b4e27c4dda661e2e6",
#       "label": "missed0conftest",
#       "vout": 0
#     }
#   ],
#   "hex": "02000...1ece40000",
#   "decoded": {
#     "txid": "f91fd39733dcdcc53a4ac465829f22d69896a76f46b67b0cd301b295e1d428d0",
#     "hash": "8875cbef3ee73ef150f0bc33f822404740e7609e3f9bc43c0ef24c551046a055",
#     "wtxid": "8875cbef3ee73ef150f0bc33f822404740e7609e3f9bc43c0ef24c551046a055",
#     "withash": "33abc2818ef86c1f58f5f452820b96467acfbcee2c2acc4b7cabaf9bb317f50e",
#     "version": 2,
#     "size": 9157,
#     "vsize": 2575,
#     "weight": 10300,
#     "locktime": 107,
#     "vin": [
#       {
#         "txid": "933cdffc23f1e16547b83e40780e947eedaaf7d3cd9ea8a8bd55789f17a309c1",
#         "vout": 1,
#         "scriptSig": {
#           "asm": "",
#           "hex": ""
#         },
#         "is_pegin": false,
#         "sequence": 4294967293,
#         "txinwitness": [
#           "3044022002b341231a2b241d553f851e8c1badc608351ce1467f76889b3c9175ceab6b0402200308b3da02815c2b46e478c6e4c9c408757a99e1682fb478cc1efb8f50c0a4ae01",
#           "0271177c9995dad623e726298c2006e3b77a63995cb43900db4b6def4c40b7de96"
#         ]
#       },
#       {
#         "txid": "933cdffc23f1e16547b83e40780e947eedaaf7d3cd9ea8a8bd55789f17a309c1",
#         "vout": 0,
#         "scriptSig": {
#           "asm": "",
#           "hex": ""
#         },
#         "is_pegin": false,
#         "sequence": 4294967293,
#         "txinwitness": [
#           "304402201f79297856c1db225c8da1ee4260c214d143dc949a5e01c5435560ec7a7bb68d022046f010af483710b77f03378e4f12cdade84c76769786917242d8d5ca115695ab01",
#           "02ec65565f1632f38d0eb11e88a2e4431cc8bfa7a4fb97ee191423218663ad8c10"
#         ]
#       }
#     ],
#     "vout": [
#       {
#         "value-minimum": 1e-08,
#         "value-maximum": 45035996.27370496,
#         "ct-exponent": 0,
#         "ct-bits": 52,
#         "surjectionproof": "020003befe46bee1f08ec92a42b8bf48f8099b4c3b0e08a4ae0f1cf67e9850e31dcc0f27e5ca79b549217012f951a7ff1ddf03a8284e282d32b91db1b3ecc215ed89b5c099bf6352e7f5bbca41533a5ab26ca2722687e95f828ca51383dd6201c683fc",
#         "valuecommitment": "08dca08c7b1efb2ccbdd428233fc8e5ef95fcf7d73f6b87a08436dc5909b6bf9b9",
#         "assetcommitment": "0b2a8b9f96d9e6d0313e6b580a77bcaa4ade7d0091cde1f0c0ea6ec96d48463432",
#         "commitmentnonce": "034ed2b9622f3941bc82ad49a21de73eb58888d642e668a715e27233350fdaa040",
#         "commitmentnonce_fully_valid": true,
#         "n": 0,
#         "scriptPubKey": {
#           "asm": "0 45f71826eca61035b3d3b7d2868cdbb07679fa49",
#           "desc": "addr(ert1qghm3sfhv5cgrtv7nklfgdrxmkpm8n7jf7pzxp5)#g2v8jt3t",
#           "hex": "001445f71826eca61035b3d3b7d2868cdbb07679fa49",
#           "address": "ert1qghm3sfhv5cgrtv7nklfgdrxmkpm8n7jf7pzxp5",
#           "type": "witness_v0_keyhash"
#         }
#       },
#       {
#         "value-minimum": 1e-08,
#         "value-maximum": 45035996.27370496,
#         "ct-exponent": 0,
#         "ct-bits": 52,
#         "surjectionproof": "020003dc137e7fe4aee41f3dd71f99e6ca1e65ff22fc537af28ee86e8bc8639c11bd68d81c2a35f92dcba65ee7b118e42f2e68645d7bb931f6899bf81d25af6e443876a7693bb6d3258995ed63f7d4b832feb9e0f70f267b160870c737ec020af5fe7a",
#         "valuecommitment": "09924933780b2ab0d9519faa64aa403b90261b62abe61b7db7283fd22bfa947378",
#         "assetcommitment": "0a0570184a71514fdce8c87e50e1af454d9375282b4f3f10c9d94f59ca74c440a5",
#         "commitmentnonce": "02cbd6d3415c583495dd40a78749d4ce6aba404685a438f5f0d539b2435011417f",
#         "commitmentnonce_fully_valid": true,
#         "n": 1,
#         "scriptPubKey": {
#           "asm": "0 724dd8a02c7a7b33e2f8848afb76090c357c5367",
#           "desc": "addr(ert1qwfxa3gpv0fan8chcsj90kasfps6hc5m84ep9uw)#nwnr9ftd",
#           "hex": "0014724dd8a02c7a7b33e2f8848afb76090c357c5367",
#           "address": "ert1qwfxa3gpv0fan8chcsj90kasfps6hc5m84ep9uw",
#           "type": "witness_v0_keyhash"
#         }
#       },
#       {
#         "value": 2.58e-06,
#         "asset": "b2e15d0d7a0c94e4e2ce0fe6e8691b9e451377f6e46e8045a86f7c4b5d4f0f23",
#         "commitmentnonce": "",
#         "commitmentnonce_fully_valid": false,
#         "n": 2,
#         "scriptPubKey": {
#           "asm": "",
#           "desc": "raw()#58lrscpx",
#           "hex": "",
#           "type": "fee"
#         }
#       }
#     ],
#     "fee": {
#       "b2e15d0d7a0c94e4e2ce0fe6e8691b9e451377f6e46e8045a86f7c4b5d4f0f23": 2.58e-06
#     }
#   }
# }
#

# 2: boolean bypass_callbacks (optional)
#

elements_confirmation() {
  trace "[elements_confirmation] Entering elements_confirmation()..."

  local tx_details=$(echo "${1}" | base64 -d)
  local bypass_callbacks=${2}

  trace "[elements_confirmation] tx_details=${tx_details}"
  trace "[elements_confirmation] bypass_callbacks=${bypass_callbacks}"

  local returncode
  local txid=$(echo "${tx_details}" | jq -r ".txid")

  (
  local returncode
  local flock_output

  flock_output=$(flock --verbose --timeout 60 9 2>&1)
  returncode=$?
  trace "[elements_confirmation] flock_output=${flock_output}"
  if [ "$returncode" -eq "0" ]; then
    ########################################################################################################
    # First of all, let's make sure we're working on watched addresses...
    local address
    local addresseswhere
    local addresses=$(echo "${tx_details}" | jq -r ".details[].address")

    trace "[elements_confirmation] addresses=${addresses}"

    local notfirst=false
    local IFS="
"
    for address in ${addresses}
    do
      trace "[elements_confirmation] address=${address}"

      if ${notfirst}; then
        addresseswhere="${addresseswhere},'${address}'"
      else
        addresseswhere="'${address}'"
        notfirst=true
      fi
    done
    local rows=$(sql "SELECT id, address, unblinded_address, elements_watching_by_pub32_id, pub32_index, event_message, watching_assetid FROM elements_watching WHERE watching AND (address IN (${addresseswhere}) OR unblinded_address IN (${addresseswhere}))")
    if [ ${#rows} -eq 0 ]; then
      trace "[elements_confirmation] No watched address in this tx!"
      return 0
    fi
    ########################################################################################################

    local tx=$(sql "SELECT id FROM elements_tx WHERE txid='${txid}'")
    local id_inserted
    local tx_nb_conf=$(echo "${tx_details}" | jq -r '.confirmations // 0')
    local tx_hash=$(echo "${tx_details}" | jq -r '.decoded.hash')
    trace "[elements_confirmation] tx_hash=${tx_hash}"

    if [ -z ${tx} ]; then
      # TX not found in our DB.
      # 0-conf or missed conf (managed or while spending) or spending an unconfirmed
      # (note: spending an unconfirmed TX must be avoided or we'll get here spending an unprocessed watching)

      # Let's first insert the tx in our DB

      local tx_ts_firstseen=$(echo "${tx_details}" | jq '.timereceived')
      local tx_amount=$(echo "${tx_details}" | jq '.amount.bitcoin | fabs')

      local tx_size=$(echo "${tx_details}" | jq '.decoded.size')
      local tx_vsize=$(echo "${tx_details}" | jq '.decoded.vsize')
      local tx_replaceable=$(echo "${tx_details}" | jq -r '."bip125-replaceable"')
      tx_replaceable=$([ ${tx_replaceable} = "yes" ] && echo "true" || echo "false")

      # The fees in elements are unblinded
      local fees=$(echo "${tx_details}" | jq '.decoded.fee."6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d" | fabs' | awk '{ printf "%.8f", $0 }')
#      local fees=$(echo "${tx_details}" | jq '.fee.bitcoin | fabs' | awk '{ printf "%.8f", $0 }')
      trace "[elements_confirmation] fees=${fees}"

      # If we missed 0-conf...
      local tx_blockhash=null
      local tx_blockheight=null
      local tx_blocktime=null
      if [ "${tx_nb_conf}" -gt "0" ]; then
        trace "[elements_confirmation] tx_nb_conf=${tx_nb_conf}"
        tx_blockhash="$(echo "${tx_details}" | jq -r '.blockhash')"
        tx_blockheight="$(echo "${tx_details}" | jq -r '.blockheight')"
        tx_blockhash="'${tx_blockhash}'"
        tx_blocktime=$(echo "${tx_details}" | jq '.blocktime')
      fi

      id_inserted=$(sql "INSERT INTO elements_tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, blockhash, blockheight, blocktime)"\
" VALUES ('${txid}', '${tx_hash}', ${tx_nb_conf}, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, ${tx_blockhash}, ${tx_blockheight}, ${tx_blocktime})"\
" ON CONFLICT (txid) DO"\
" UPDATE SET blockhash=${tx_blockhash}, blockheight=${tx_blockheight}, blocktime=${tx_blocktime}, confirmations=${tx_nb_conf}"\
" RETURNING id" \
      "SELECT id FROM elements_tx WHERE txid='${txid}'")
      trace_rc $?

    else
      # TX found in our DB.
      # 1-conf or executecallbacks on an unconfirmed tx or spending watched address (in this case, we probably missed conf) or spending to a watched address (in this case, spend inserted the tx in the DB)

      local tx_blockhash=$(echo "${tx_details}" | jq -r '.blockhash')
      trace "[elements_confirmation] tx_blockhash=${tx_blockhash}"
      if [ "${tx_blockhash}" = "null" ]; then
        trace "[elements_confirmation] probably being called by executecallbacks without any confirmations since the last time we checked"
      else
        local tx_blockheight="$(echo "${tx_details}" | jq -r '.blockheight')"
        local tx_blocktime=$(echo "${tx_details}" | jq '.blocktime')

        sql "UPDATE elements_tx SET confirmations=${tx_nb_conf}, blockhash='${tx_blockhash}', blockheight=${tx_blockheight}, blocktime=${tx_blocktime} WHERE txid='${txid}'"
        trace_rc $?
      fi
      id_inserted=${tx}
    fi

    ########################################################################################################

    local event_message
    local watching_id
    local unblinded_address

    # Let's see if we need to insert tx in the join table

    for row in ${rows}
    do
      watching_id=$(echo "${row}" | cut -d '|' -f1)
      tx=$(sql "SELECT elements_tx_id FROM elements_watching_tx WHERE elements_tx_id=${id_inserted} and elements_watching_id=${watching_id}")

      address=$(echo "${row}" | cut -d '|' -f2)
      unblinded_address=$(echo "${row}" | cut -d '|' -f3)
      tx_vout_amount=$(echo "${tx_details}" | jq ".details | map(select(.address==\"${unblinded_address}\"))[0] | .amount | fabs" | awk '{ printf "%.8f", $0 }')
      # In the case of us spending to a watched address, the address appears twice in the details,
      # once on the spend side (negative amount) and once on the receiving side (positive amount)
      tx_vout_n=$(echo "${tx_details}" | jq ".details | map(select(.address==\"${unblinded_address}\"))[0] | .vout")
      tx_vout_assetid=$(echo "${tx_details}" | jq -r ".details | map(select(.address==\"${unblinded_address}\"))[0] | .asset")

      ########################################################################################################
      # Let's now insert in the join table if not already done
      if [ -z "${tx}" ]; then
        trace "[elements_confirmation] For this tx, there's no watching_tx row, let's create it"

        # If the tx is batched and pays multiple watched addresses, we have to insert
        # those additional addresses in watching_tx!
        sql "INSERT INTO elements_watching_tx (elements_watching_id, elements_tx_id, vout, amount, assetid) VALUES (${watching_id}, ${id_inserted}, ${tx_vout_n}, ${tx_vout_amount}, '${tx_vout_assetid}')"\
" ON CONFLICT DO NOTHING"
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
        elements_extend_watchers "${watching_by_pub32_id}" "${pub32_index}"
      fi
      ########################################################################################################

      ########################################################################################################
      # Let's publish the event if needed
      event_message=$(echo "${row}" | cut -d '|' -f6)
      watching_assetid=$(echo "${row}" | cut -d '|' -f7)
      if [ -n "${event_message}" ]; then
        # There's an event message, let's publish it!

        trace "[elements_confirmation] mosquitto_pub -h broker -t elements_tx_confirmation -m \"{\"txid\":\"${txid}\",\"hash\":\"${tx_hash}\",\"address\":\"${address}\",\"unblindedAddress\":\"${unblinded_address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"watchingAssetId\":\"${watching_assetid}\",\"assetId\":\"${tx_vout_assetid}\",\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}\""
        response=$(mosquitto_pub -h broker -t elements_tx_confirmation -m "{\"txid\":\"${txid}\",\"hash\":\"${tx_hash}\",\"address\":\"${address}\",\"unblindedAddress\":\"${unblinded_address}\",\"vout_n\":${tx_vout_n},\"amount\":${tx_vout_amount},\"watchingAssetId\":\"${watching_assetid}\",\"assetId\":\"${tx_vout_assetid}\",\"confirmations\":${tx_nb_conf},\"eventMessage\":\"${event_message}\"}")
        returncode=$?
        trace_rc ${returncode}
      fi
      ########################################################################################################

    done
  else
    trace "[confirmation]  Exiting flock"
  fi
  ) 9>./.elements_confirmation.lock

  # There's a lock in callbacks, let's get out of the confirmation lock before entering another one
  # If this was called by missed_conf algo, we don't want to process all the callbacks now.  We wait
  # for next cron.
  if [ -z "${bypass_callbacks}" ]; then
    trace "[elements_confirmation] Let's do the callbacks!"
    elements_do_callbacks "${txid}"
  else
    trace "[elements_confirmation] Skipping callbacks as requested"
  fi

  echo '{"result":"confirmed"}'

  return 0
}

case "${0}" in *elements_confirmation.sh) elements_confirmation "$@";; esac
