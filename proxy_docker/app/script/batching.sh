#!/bin/sh

. ./trace.sh
. ./sendtobitcoinnode.sh

createbatcher() {
  trace "Entering createbatcher()..."

  # POST http://192.168.111.152:8080/createbatcher
  #
  # args:
  # - batcherLabel, optional, id can be used to reference the batcher
  # - confTarget, optional, overriden by batchspend's confTarget, default Bitcoin Core conf_target will be used if not supplied
  # NOTYET - feeRate, sat/vB, optional, overrides confTarget if supplied, overriden by batchspend's feeRate, default Bitcoin Core fee policy will be used if not supplied
  #
  # response:
  # - batcherId, the batcher id
  #
  # BODY {"batcherLabel":"lowfees","confTarget":32}
  # NOTYET BODY {"batcherLabel":"highfees","feeRate":231.8}

  local request=${1}
  local response
  local label=$(echo "${request}" | jq ".batcherLabel")
  trace "[createbatcher] label=${label}"
  local conf_target=$(echo "${request}" | jq ".confTarget")
  trace "[createbatcher] conf_target=${conf_target}"
  local feerate=$(echo "${request}" | jq ".feeRate")
  trace "[createbatcher] feerate=${feerate}"

  # if [ "${feerate}" != "null" ]; then
  #   # If not null, let's nullify conf_target since feerate overrides it
  #   conf_target="null"
  #   trace "[createbatcher] Overriding conf_target=${conf_target}"
  # fi

  local batcher_id

  batcher_id=$(sql "INSERT OR IGNORE INTO batcher (label, conf_target, feerate) VALUES (${label}, ${conf_target}, ${feerate}); SELECT LAST_INSERT_ROWID();")

  if ("${batcher_id}" -eq "0"); then
    trace "[createbatcher] Could not insert"
    response='{"result":null,"error":{"code":-32700,"message":"Could not create batcher, label probably already exists","data":'${request}'}}'
  else
    trace "[createbatcher] Inserted"
    response='{"result":{"batcherId":'${batcher_id}'},"error":null}'
  fi

  echo "${response}"
}

updatebatcher() {
  trace "Entering updatebatcher()..."

  # POST http://192.168.111.152:8080/updatebatcher
  #
  # args:
  # - batcherId, optional, batcher id to update, will update default batcher if not supplied
  # - batcherLabel, optional, id can be used to reference the batcher, will update default batcher if not supplied, if id is present then change the label with supplied text
  # - confTarget, optional, new confirmation target for the batcher
  # NOTYET - feeRate, sat/vB, optional, new feerate for the batcher
  #
  # response:
  # - batcherId, the batcher id
  # - batcherLabel, the batcher label
  # - confTarget, the batcher default confirmation target
  # NOTYET - feeRate, the batcher default feerate
  #
  # BODY {"batcherId":5,"confTarget":12}
  # NOTYET BODY {"batcherLabel":"highfees","feeRate":400}
  # NOTYET BODY {"batcherId":3,"batcherLabel":"ultrahighfees","feeRate":800}
  # BODY {"batcherLabel":"fast","confTarget":2}

  local request=${1}
  local response
  local whereclause
  local returncode

  local id=$(echo "${request}" | jq ".batcherId")
  trace "[updatebatcher] id=${id}"
  local label=$(echo "${request}" | jq ".batcherLabel")
  trace "[updatebatcher] label=${label}"
  local conf_target=$(echo "${request}" | jq ".confTarget")
  trace "[updatebatcher] conf_target=${conf_target}"
  local feerate=$(echo "${request}" | jq ".feeRate")
  trace "[updatebatcher] feerate=${feerate}"

  if [ "${id}" = "null" ] && [ "${label}" = "null" ]; then
    # If id and label are null, use default batcher
    trace "[updatebatcher] Using default batcher 1"
    id=1
  fi

  # if [ "${feerate}" != "null" ]; then
  #   # If not null, let's nullify conf_target since feerate overrides it
  #   conf_target="null"
  #   trace "[updatebatcher] Overriding conf_target=${conf_target}"
  # fi

  if [ "${id}" = "null" ]; then
    whereclause="label=${label}"
  else
    whereclause="id = ${id}"
  fi

  sql "UPDATE batcher set label=${label}, conf_target=${conf_target}, feerate=${feerate} WHERE ${whereclause}"
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -ne 0 ]; then
    response='{"result":null,"error":{"code":-32700,"message":"Could not update batcher","data":'${request}'}}'
  else
    response='{"result":{"batcherId":'${id}'},"error":null}'
  fi

  echo "${response}"
}

addtobatch() {
  trace "Entering addtobatch()..."

  # POST http://192.168.111.152:8080/addtobatch
  #
  # args:
  # - address, required, desination address
  # - amount, required, amount to send to the destination address
  # - outputLabel, optional, if you want to reference this output
  # - batcherId, optional, the id of the batcher to which the output will be added, default batcher if not supplied, overrides batcherLabel
  # - batcherLabel, optional, the label of the batcher to which the output will be added, default batcher if not supplied
  # - webhookUrl, optional, the webhook to call when the batch is broadcast
  #
  # response:
  # - batcherId, the id of the batcher
  # - outputId, the id of the added output
  # - nbOutputs, the number of outputs currently in the batch
  # - oldest, the timestamp of the oldest output in the batch
  # - total, the current sum of the batch's output amounts
  #
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherId":34,"webhookUrl":"https://myCypherApp:3000/batchExecuted"}
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherLabel":"lowfees","webhookUrl":"https://myCypherApp:3000/batchExecuted"}
  # BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherId":34,"webhookUrl":"https://myCypherApp:3000/batchExecuted"}

  local request=${1}
  local response
  local returncode=0
  local inserted_id
  local row

  local address=$(echo "${request}" | jq -r ".address")
  trace "[addtobatch] address=${address}"
  local amount=$(echo "${request}" | jq ".amount")
  trace "[addtobatch] amount=${amount}"
  local label=$(echo "${request}" | jq ".outputLabel")
  trace "[addtobatch] label=${label}"
  local batcher_id=$(echo "${request}" | jq ".batcherId")
  trace "[addtobatch] batcher_id=${batcher_id}"
  local batcher_label=$(echo "${request}" | jq ".batcherLabel")
  trace "[addtobatch] batcher_label=${batcher_label}"
  local webhook_url=$(echo "${request}" | jq ".webhookUrl")
  trace "[addtobatch] webhook_url=${webhook_url}"

  local isvalid
  isvalid=$(validateaddress "${address}" | jq ".result.isvalid")
  if [ "${isvalid}" != "true" ]; then

    response='{"result":null,"error":{"code":-32700,"message":"Invalid address","data":'${request}'}}'

    trace "[addtobatch] Invalid address"
    trace "[addtobatch] responding=${response}"

    echo "${response}"

    return 1
  fi

  if [ "${batcher_id}" = "null" ] && [ "${batcher_label}" = "null" ]; then
    # If batcher_id and batcher_label are null, use default batcher
    trace "[addtobatch] Using default batcher 1"
    batcher_id=1
  fi

  if [ "${batcher_id}" = "null" ]; then
    # Using batcher_label
    batcher_id=$(sql "SELECT id FROM batcher WHERE label=${batcher_label}")
    returncode=$?
    trace_rc ${returncode}
  fi

  if [ -z "${batcher_id}" ]; then
    # batcherLabel not found
    response='{"result":null,"error":{"code":-32700,"message":"batcher not found","data":'${request}'}}'
  else
    inserted_id=$(sql "INSERT INTO recipient (address, amount, webhook_url, batcher_id, label) VALUES (\"${address}\", ${amount}, ${webhook_url}, ${batcher_id}, ${label}); SELECT LAST_INSERT_ROWID();")
    returncode=$?
    trace_rc ${returncode}

    if [ "${returncode}" -ne 0 ]; then
      response='{"result":null,"error":{"code":-32700,"message":"Could not add to batch","data":'${request}'}}'
    else
      row=$(sql "SELECT COUNT(id), MIN(inserted_ts), SUM(amount) FROM recipient WHERE tx_id IS NULL AND batcher_id=${batcher_id}")
      returncode=$?
      trace_rc ${returncode}

      local count=$(echo "${row}" | cut -d '|' -f1)
      trace "[addtobatch] count=${count}"
      local oldest=$(echo "${row}" | cut -d '|' -f2)
      trace "[addtobatch] oldest=${oldest}"
      local total=$(echo "${row}" | cut -d '|' -f3)
      trace "[addtobatch] total=${total}"

      response='{"result":{"batcherId":'${batcher_id}',"outputId":'${inserted_id}',"nbOutputs":'${count}',"oldest":"'${oldest}'","total":'${total}'},"error":null}'
    fi
  fi

  echo "${response}"
}

removefrombatch() {
  trace "Entering removefrombatch()..."

  # POST http://192.168.111.152:8080/removefrombatch
  #
  # args:
  # - outputId, required, id of the output to remove
  #
  # response:
  # - batcherId, the id of the batcher
  # - outputId, the id of the removed output if found
  # - nbOutputs, the number of outputs currently in the batch
  # - oldest, the timestamp of the oldest output in the batch
  # - total, the current sum of the batch's output amounts
  #
  # BODY {"id":72}

  local request=${1}
  local response
  local returncode=0
  local row
  local batcher_id

  local id=$(echo "${request}" | jq ".outputId")
  trace "[removefrombatch] id=${id}"

  if [ "${id}" = "null" ]; then
    # id is required
    trace "[removefrombatch] id missing"
    response='{"result":null,"error":{"code":-32700,"message":"outputId is required","data":'${request}'}}'
  else
    batcher_id=$(sql "SELECT batcher_id FROM recipient WHERE id=${id}")
    returncode=$?
    trace_rc ${returncode}

    if [ -n "${batcher_id}" ]; then
      sql "DELETE FROM recipient WHERE id=${id}"
      returncode=$?
      trace_rc ${returncode}

      if [ "${returncode}" -ne 0 ]; then
        response='{"result":null,"error":{"code":-32700,"message":"Output was not removed","data":'${request}'}}'
      else
        row=$(sql "SELECT COUNT(id), COALESCE(MIN(inserted_ts), 0), COALESCE(SUM(amount), 0.00000000) FROM recipient WHERE tx_id IS NULL AND batcher_id=${batcher_id}")
        returncode=$?
        trace_rc ${returncode}

        local count=$(echo "${row}" | cut -d '|' -f1)
        trace "[removefrombatch] count=${count}"
        local oldest=$(echo "${row}" | cut -d '|' -f2)
        trace "[removefrombatch] oldest=${oldest}"
        local total=$(echo "${row}" | cut -d '|' -f3)
        trace "[removefrombatch] total=${total}"

        response='{"result":{"batcherId":'${batcher_id}',"outputId":'${id}',"nbOutputs":'${count}',"oldest":"'${oldest}'","total":'${total}'},"error":null}'
      fi
    else
      response='{"result":null,"error":{"code":-32700,"message":"Output not found or already spent","data":'${request}'}}'
    fi
  fi

  echo "${response}"
}

batchspend() {
  trace "Entering batchspend()..."

  # POST http://192.168.111.152:8080/batchspend
  #
  # args:
  # - batcherId, optional, id of the batcher to execute, overrides batcherLabel, default batcher will be spent if not supplied
  # - batcherLabel, optional, label of the batcher to execute, default batcher will be executed if not supplied
  # - confTarget, optional, overrides default value of createbatcher, default to value of createbatcher, default Bitcoin Core conf_target will be used if not supplied
  # NOTYET - feeRate, optional, overrides confTarget if supplied, overrides default value of createbatcher, default to value of createbatcher, default Bitcoin Core value will be used if not supplied
  #
  # response:
  # - txid, the txid of the batch
  # - nbOutputs, the number of outputs spent in the batch
  # - oldest, the timestamp of the oldest output in the spent batch
  # - total, the sum of the spent batch's output amounts
  # - txid, the transaction txid
  # - hash, the transaction hash
  # - tx details: size, vsize, replaceable, fee
  # - outputs
  #
  # BODY {}
  # BODY {"batcherId":"34","confTarget":12}
  # NOTYET BODY {"batcherLabel":"highfees","feeRate":233.7}
  # BODY {"batcherId":"411","confTarget":6}

  local request=${1}
  local response
  local returncode=0
  local row
  local whereclause

  local batcher_id=$(echo "${request}" | jq ".batcherId")
  trace "[batchspend] batcher_id=${batcher_id}"
  local batcher_label=$(echo "${request}" | jq ".batcherLabel")
  trace "[batchspend] batcher_label=${batcher_label}"
  local conf_target=$(echo "${request}" | jq ".confTarget")
  trace "[batchspend] conf_target=${conf_target}"
  local feerate=$(echo "${request}" | jq ".feeRate")
  trace "[batchspend] feerate=${feerate}"

  if [ "${batcher_id}" = "null" ] && [ "${batcher_label}" = "null" ]; then
    # If batcher_id and batcher_label are null, use default batcher
    trace "[batchspend] Using default batcher 1"
    batcher_id=1
  fi

  if [ "${batcher_id}" = "null" ]; then
    # Using batcher_label
    whereclause="label=${batcher_label}"
  else
    whereclause="id=${batcher_id}"
  fi

  local batcher=$(sql "SELECT id, conf_target, feerate FROM batcher WHERE ${whereclause}")
  returncode=$?
  trace_rc ${returncode}

  if [ -z "${batcher}" ]; then
    # batcherLabel not found
    response='{"result":null,"error":{"code":-32700,"message":"batcher not found","data":'${request}'}}'
  else
    # All good, let's try to batch spend!

    # NOTYET
    # We'll use supplied feerate
    # If not supplied, we'll use supplied conf_target
    # If not supplied, we'll use batcher default feerate
    # If not set, we'll use batcher default conf_target
    # If not set, default Bitcoin Core fee policy will be used

    # We'll use the supplied conf_target
    # If not supplied, we'll use the batcher default conf_target
    # If not set, default Bitcoin Core fee policy will be used

    # if [ "${feerate}" != "null" ]; then
    #   # If not null, let's nullify conf_target since feerate overrides it
    #   conf_target=
    #   trace "[batchspend] Overriding conf_target=${conf_target}"
    # else
    #   if [ "${conf_target}" = "null" ]; then
    #     feerate=$(echo "${batcher}" | cut -d '|' -f3)
    #     if [ -z "${feerate}" ]; then
    #       # If null, let's use batcher conf_target
    #       conf_target=$(echo "${batcher}" | cut -d '|' -f2)
    #     fi
    #   fi
    # fi

    if [ "${conf_target}" = "null" ]; then
      conf_target=$(echo "${batcher}" | cut -d '|' -f2)
      trace "[batchspend] Using batcher default conf_target=${conf_target}"
    fi

    batcher_id=$(echo "${batcher}" | cut -d '|' -f1)

    local batching=$(sql "SELECT address, amount, id, webhook_url FROM recipient WHERE tx_id IS NULL AND batcher_id=${batcher_id}")
    trace "[batchspend] batching=${batching}"

    local data
    local recipientsjson
    local webhooks_data
    local id_inserted
    local tx_details
    local tx_raw_details
    local address
    local amount
    local IFS=$'\n'
    for row in ${batching}
    do
      trace "[batchspend] row=${row}"
      address=$(echo "${row}" | cut -d '|' -f1)
      trace "[batchspend] address=${address}"
      amount=$(echo "${row}" | cut -d '|' -f2)
      trace "[batchspend] amount=${amount}"
      recipient_id=$(echo "${row}" | cut -d '|' -f3)
      trace "[batchspend] recipient_id=${recipient_id}"
      webhook_url=$(echo "${row}" | cut -d '|' -f4)
      trace "[batchspend] webhook_url=${webhook_url}"

      if [ -z "${recipientsjson}" ]; then
        whereclause="\"${recipient_id}\""
        recipientsjson="\"${address}\":${amount}"
        webhooks_data="{\"outputId\":${recipient_id},\"address\":\"${address}\",\"amount\":${amount},\"webhookUrl\":\"${webhook_url}\"}"
      else
        whereclause="${whereclause},\"${recipient_id}\""
        recipientsjson="${recipientsjson},\"${address}\":${amount}"
        webhooks_data="${webhooks_data},{\"outputId\":${recipient_id},\"address\":\"${address}\",\"amount\":${amount},\"webhookUrl\":\"${webhook_url}\"}"
      fi
    done

    local bitcoincore_args="{\"method\":\"sendmany\",\"params\":[\"\", {${recipientsjson}}"
    if [ -n "${conf_target}" ]; then
      bitcoincore_args="${bitcoincore_args}, 1, \"\", null, null, ${conf_target}"
    fi
    bitcoincore_args="${bitcoincore_args}]}"
    data=$(send_to_spender_node "${bitcoincore_args}")
    returncode=$?
    trace_rc ${returncode}
    trace "[batchspend] data=${data}"

    if [ "${returncode}" -eq 0 ]; then
      local txid=$(echo "${data}" | jq -r ".result")
      trace "[batchspend] txid=${txid}"

      # Let's get transaction details on the spending wallet so that we have fee information
      tx_details=$(get_transaction ${txid} "spender")
      tx_raw_details=$(get_rawtransaction ${txid})

      # Amounts and fees are negative when spending so we absolute those fields
      local tx_hash=$(echo "${tx_raw_details}" | jq '.result.hash')
      local tx_ts_firstseen=$(echo "${tx_details}" | jq '.result.timereceived')
      local tx_amount=$(echo "${tx_details}" | jq '.result.amount | fabs' | awk '{ printf "%.8f", $0 }')
      local tx_size=$(echo "${tx_raw_details}" | jq '.result.size')
      local tx_vsize=$(echo "${tx_raw_details}" | jq '.result.vsize')
      local tx_replaceable=$(echo "${tx_details}" | jq -r '.result."bip125-replaceable"')
      trace "[batchspend] tx_replaceable=${tx_replaceable}"
      tx_replaceable=$([ "${tx_replaceable}" = "yes" ] && echo "true" || echo "false")
      trace "[batchspend] tx_replaceable=${tx_replaceable}"
      local fees=$(echo "${tx_details}" | jq '.result.fee | fabs' | awk '{ printf "%.8f", $0 }')
      # Sometimes raw tx are too long to be passed as paramater, so let's write
      # it to a temp file for it to be read by sqlite3 and then delete the file
      echo "${tx_raw_details}" > batchspend-rawtx-${txid}.blob

      # Get the info on the batch before setting it to done
      row=$(sql "SELECT COUNT(id), COALESCE(MIN(inserted_ts), 0), COALESCE(SUM(amount), 0.00000000) FROM recipient WHERE tx_id IS NULL AND batcher_id=${batcher_id}")

      # Let's insert the txid in our little DB -- then we'll already have it when receiving confirmation
      id_inserted=$(sql "INSERT OR IGNORE INTO tx (txid, hash, confirmations, timereceived, fee, size, vsize, is_replaceable, raw_tx) VALUES (\"${txid}\", ${tx_hash}, 0, ${tx_ts_firstseen}, ${fees}, ${tx_size}, ${tx_vsize}, ${tx_replaceable}, readfile('batchspend-rawtx-${txid}.blob')); SELECT LAST_INSERT_ROWID();")
      returncode=$?
      trace_rc ${returncode}
      if [ "${returncode}" -eq 0 ]; then
        if [ "${id_inserted}" -eq 0 ]; then
          id_inserted=$(sql "SELECT id FROM tx WHERE txid=\"${txid}\"")
        fi
        trace "[batchspend] id_inserted: ${id_inserted}"
        sql "UPDATE recipient SET tx_id=${id_inserted} WHERE id IN (${whereclause})"
        trace_rc $?
      fi

      # Use the selected row above (before the insert)
      local count=$(echo "${row}" | cut -d '|' -f1)
      trace "[batchspend] count=${count}"
      local oldest=$(echo "${row}" | cut -d '|' -f2)
      trace "[batchspend] oldest=${oldest}"
      local total=$(echo "${row}" | cut -d '|' -f3)
      trace "[batchspend] total=${total}"

      response='{"result":{"batcherId":'${batcher_id}',"confTarget":'${conf_target}',"nbOutputs":'${count}',"oldest":"'${oldest}'","total":'${total}
      response="${response},\"txid\":\"${txid}\",\"hash\":${tx_hash},\"details\":{\"firstseen\":${tx_ts_firstseen},\"size\":${tx_size},\"vsize\":${tx_vsize},\"replaceable\":${tx_replaceable},\"fee\":${fees}},\"outputs\":{${recipientsjson}}}"
      response="${response},\"error\":null}"

      # Delete the temp file containing the raw tx (see above)
      rm batchspend-rawtx-${txid}.blob

      batch_webhooks "[${webhooks_data}]" '"batcherId":'${batcher_id}',"txid":"'${txid}'","hash":'${tx_hash}',"details":{"firstseen":'${tx_ts_firstseen}',"size":'${tx_size}',"vsize":'${tx_vsize}',"replaceable":'${tx_replaceable}',"fee":'${fees}'}'

    else
      local message=$(echo "${data}" | jq -e ".error.message")
      response='{"result":null,"error":{"code":-32700,"message":'${message}',"data":'${request}'}}'
    fi
  fi

  trace "[batchspend] responding=${response}"
  echo "${response}"
}

batch_check_webhooks() {
  trace "Entering batch_check_webhooks()..."

  local webhooks_data
  local address
  local amount
  local recipient_id
  local webhook_url
  local batcher_id
  local txid
  local tx_hash
  local tx_ts_firstseen
  local tx_size
  local tx_vsize
  local tx_replaceable
  local fees

  local batching=$(sql "SELECT address, amount, r.id, webhook_url, b.id, t.txid, t.hash, t.timereceived, t.fee, t.size, t.vsize, t.is_replaceable FROM recipient r, batcher b, tx t WHERE r.batcher_id=b.id AND r.tx_id=t.id AND NOT calledback AND tx_id IS NOT NULL AND webhook_url IS NOT NULL")
  trace "[batch_check_webhooks] batching=${batching}"

  local IFS=$'\n'
  for row in ${batching}
  do
    trace "[batch_check_webhooks] row=${row}"
    address=$(echo "${row}" | cut -d '|' -f1)
    trace "[batch_check_webhooks] address=${address}"
    amount=$(echo "${row}" | cut -d '|' -f2)
    trace "[batch_check_webhooks] amount=${amount}"
    recipient_id=$(echo "${row}" | cut -d '|' -f3)
    trace "[batch_check_webhooks] recipient_id=${recipient_id}"
    webhook_url=$(echo "${row}" | cut -d '|' -f4)
    trace "[batch_check_webhooks] webhook_url=${webhook_url}"
    batcher_id=$(echo "${row}" | cut -d '|' -f5)
    trace "[batch_check_webhooks] batcher_id=${batcher_id}"
    txid=$(echo "${row}" | cut -d '|' -f6)
    trace "[batch_check_webhooks] txid=${txid}"
    tx_hash=$(echo "${row}" | cut -d '|' -f7)
    trace "[batch_check_webhooks] tx_hash=${tx_hash}"
    tx_ts_firstseen=$(echo "${row}" | cut -d '|' -f8)
    trace "[batch_check_webhooks] tx_ts_firstseen=${tx_ts_firstseen}"
    tx_size=$(echo "${row}" | cut -d '|' -f9)
    trace "[batch_check_webhooks] tx_size=${tx_size}"
    tx_vsize=$(echo "${row}" | cut -d '|' -f10)
    trace "[batch_check_webhooks] tx_vsize=${tx_vsize}"
    tx_replaceable=$(echo "${row}" | cut -d '|' -f11)
    trace "[batch_check_webhooks] tx_replaceable=${tx_replaceable}"
    fees=$(echo "${row}" | cut -d '|' -f12)
    trace "[batch_check_webhooks] fees=${fees}"

    webhooks_data="{\"outputId\":${recipient_id},\"address\":\"${address}\",\"amount\":${amount},\"webhookUrl\":\"${webhook_url}\"}"

    batch_webhooks "[${webhooks_data}]" '"batcherId":'${batcher_id}',"txid":"'${txid}'","hash":"'${tx_hash}'","details":{"firstseen":'${tx_ts_firstseen}',"size":'${tx_size}',"vsize":'${tx_vsize}',"replaceable":'${tx_replaceable}',"fee":'${fees}'}'
  done
}

batch_webhooks() {
  trace "Entering batch_webhooks()..."

  # webhooks_data:
  # {"outputId":1,"address":"1abc","amount":0.12,"webhookUrl":"https://bleah.com/batchwebhook"}"
  local webhooks_data=${1}
  trace "[batch_webhooks] webhooks_data=${webhooks_data}"

  # tx:
  # {"batcherId":1,"txid":"abc123","hash":"abc123","details":{"firstseen":123123,"size":200,"vsize":141,"replaceable":true,"fee":0.00001}}'
  local tx=${2}
  trace "[batch_webhooks] tx=${tx}"

  local outputs
  local output_id
  local address
  local amount
  local webhook_url
  local body
  local successful_recipient_ids
  local returncode

  outputs=$(echo "${webhooks_data}" | jq -Mc ".[]")

  local output
  local IFS=$'\n'
  for output in ${outputs}
  do
    webhook_url=$(echo "${output}" | jq -r ".webhookUrl")
    trace "[batch_webhooks] webhook_url=${webhook_url}"

    if [ -z "${webhook_url}" ] || [ "${webhook_url}" = "null" ]; then
      trace "[batch_webhooks] Empty webhook_url, skipping"
      continue
    fi

    output_id=$(echo "${output}" | jq ".outputId")
    trace "[batch_webhooks] output_id=${output_id}"
    address=$(echo "${output}" | jq ".address")
    trace "[batch_webhooks] address=${address}"
    amount=$(echo "${output}" | jq ".amount")
    trace "[batch_webhooks] amount=${amount}"

    body='{"outputId":'${output_id}',"address":'${address}',"amount":'${amount}','${tx}'}'
    trace "[batch_webhooks] body=${body}"

    notify_web "${webhook_url}" "${body}" ${TOR_ADDR_WATCH_WEBHOOKS}
    returncode=$?
    trace_rc ${returncode}

    if [ "${returncode}" -eq 0 ]; then
      if [ -n "${successful_recipient_ids}" ]; then
        successful_recipient_ids="${successful_recipient_ids},${output_id}"
      else
        successful_recipient_ids="${output_id}"
      fi
    else
      trace "[batch_webhooks] callback failed, won't set to true in DB"
    fi
  done

  sql "UPDATE recipient SET calledback=1, calledback_ts=CURRENT_TIMESTAMP WHERE id IN (${successful_recipient_ids})"
  trace_rc $?
}

listbatchers() {
  trace "Entering listbatchers()..."

  # curl (GET) http://192.168.111.152:8080/listbatchers
  #
  # {"result":[
  #   {"batcherId":1,"batcherLabel":"default","confTarget":6,"nbOutputs":12,"oldest":123123,"total":0.86990143},
  #   {"batcherId":2,"batcherLabel":"lowfee","confTarget":32,"nbOutputs":44,"oldest":123123,"total":0.49827387},
  #   {"batcherId":3,"batcherLabel":"highfee","confTarget":2,"nbOutputs":7,"oldest":123123,"total":4.16843782}
  #  ],
  #  "error":null}


  local batchers=$(sql "SELECT b.id, '{\"batcherId\":' || b.id || ',\"batcherLabel\":\"' || b.label || '\",\"confTarget\":' || conf_target || ',\"nbOutputs\":' || COUNT(r.id) || ',\"oldest\":\"' ||COALESCE(MIN(r.inserted_ts), 0) || '\",\"total\":' ||COALESCE(SUM(amount), 0.00000000) || '}' FROM batcher b LEFT JOIN recipient r ON r.batcher_id=b.id AND r.tx_id IS NULL GROUP BY b.id")
  trace "[listbatchers] batchers=${batchers}"

  local returncode
  local response
  local batcher
  local jsonstring
  local IFS=$'\n'
  for batcher in ${batchers}
  do
    jsonstring=$(echo ${batcher} | cut -d '|' -f2)
    if [ -z "${response}" ]; then
      response='{"result":['${jsonstring}
    else
      response="${response},${jsonstring}"
    fi
  done

  response=${response}'],"error":null}'
  trace "[listbatchers] responding=${response}"
  echo "${response}"
}

getbatcher() {
  trace "Entering getbatcher()..."

  # POST (GET) http://192.168.111.152:8080/getbatcher
  #
  # args:
  # - batcherId, optional, id of the batcher, overrides batcerhLabel, default batcher will be used if not supplied
  # - batcherLabel, optional, label of the batcher, default batcher will be used if not supplied
  #
  # response:
  # {"result":{"batcherId":1,"batcherLabel":"default","confTarget":6,"nbOutputs":12,"oldest":123123,"total":0.86990143},"error":null}
  #
  # BODY {}
  # BODY {"batcherId":34}

  local request=${1}
  local response
  local returncode=0
  local batcher
  local whereclause

  local batcher_id=$(echo "${request}" | jq ".batcherId")
  trace "[getbatcher] batcher_id=${batcher_id}"
  local batcher_label=$(echo "${request}" | jq ".batcherLabel")
  trace "[getbatcher] batcher_label=${batcher_label}"

  if [ "${batcher_id}" = "null" ] && [ "${batcher_label}" = "null" ]; then
    # If batcher_id and batcher_label are null, use default batcher
    trace "[getbatcher] Using default batcher 1"
    batcher_id=1
  fi

  if [ "${batcher_id}" = "null" ]; then
    # Using batcher_label
    whereclause="b.label=${batcher_label}"
  else
    # Using batcher_id
    whereclause="b.id=${batcher_id}"
  fi

  batcher=$(sql "SELECT b.id, '{\"batcherId\":' || b.id || ',\"batcherLabel\":\"' || b.label || '\",\"confTarget\":' || conf_target || ',\"nbOutputs\":' || COUNT(r.id) || ',\"oldest\":\"' ||COALESCE(MIN(r.inserted_ts), 0) || '\",\"total\":' ||COALESCE(SUM(amount), 0.00000000) || '}' FROM batcher b LEFT JOIN recipient r ON r.batcher_id=b.id AND r.tx_id IS NULL WHERE ${whereclause} GROUP BY b.id")
  trace "[getbatcher] batcher=${batcher}"

  if [ -n "${batcher}" ]; then
    batcher=$(echo "${batcher}" | cut -d '|' -f2)
    response='{"result":'${batcher}',"error":null}'
  else
    response='{"result":null,"error":{"code":-32700,"message":"batcher not found","data":'${request}'}}'
  fi

  echo "${response}"
}

getbatchdetails() {
  trace "Entering getbatchdetails()..."

  # POST (GET) http://192.168.111.152:8080/getbatchdetails
  #
  # args:
  # - batcherId, optional, id of the batcher, overrides batcherLabel, default batcher will be used if not supplied
  # - batcherLabel, optional, label of the batcher, default batcher will be used if not supplied
  # - txid, optional, if you want the details of an executed batch, supply the batch txid, will return current pending batch
  #     if not supplied
  #
  # response:
  # {"result":{
  #    "batcherId":34,
  #    "batcherLabel":"Special batcher for a special client",
  #    "confTarget":6,
  #    "nbOutputs":83,
  #    "oldest":123123,
  #    "total":10.86990143,
  #    "txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
  #    "hash":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
  #    "details":{
  #      "firstseen":123123,
  #      "size":424,
  #      "vsize":371,
  #      "replaceable":yes,
  #      "fee":0.00004112
  #    },
  #    "outputs":[
  #      "1abc":0.12,
  #      "3abc":0.66,
  #      "bc1abc":2.848,
  #      ...
  #    ]
  #  }
  # },"error":null}
  #
  # BODY {}
  # BODY {"batcherId":34}

  local request=${1}
  local response
  local returncode=0
  local batch
  local tx
  local outputsjson
  local whereclause

  local batcher_id=$(echo "${request}" | jq ".batcherId")
  trace "[getbatchdetails] batcher_id=${batcher_id}"
  local batcher_label=$(echo "${request}" | jq ".batcherLabel")
  trace "[getbatchdetails] batcher_label=${batcher_label}"
  local txid=$(echo "${request}" | jq ".txid")
  trace "[getbatchdetails] txid=${txid}"

  if [ "${batcher_id}" = "null" ] && [ "${batcher_label}" = "null" ]; then
    # If batcher_id and batcher_label are null, use default batcher
    trace "[getbatchdetails] Using default batcher 1"
    batcher_id=1
  fi

  if [ "${batcher_id}" = "null" ]; then
    # Using batcher_label
    whereclause="b.label=${batcher_label}"
  else
    # Using batcher_id
    whereclause="b.id=${batcher_id}"
  fi

  if [ "${txid}" != "null" ]; then
    # Using txid
    whereclause="${whereclause} AND t.txid=${txid}"
  else
    # null txid
    whereclause="${whereclause} AND t.txid IS NULL"
    outerclause="AND r.tx_id IS NULL"
  fi

  # First get the batch summary
  batch=$(sql "SELECT b.id, COALESCE(t.id, NULL), '{\"batcherId\":' || b.id || ',\"batcherLabel\":\"' || b.label || '\",\"confTarget\":' || conf_target || ',\"nbOutputs\":' || COUNT(r.id) || ',\"oldest\":\"' ||COALESCE(MIN(r.inserted_ts), 0) || '\",\"total\":' ||COALESCE(SUM(amount), 0.00000000) FROM batcher b LEFT JOIN recipient r ON r.batcher_id=b.id ${outerclause} LEFT JOIN tx t ON t.id=r.tx_id WHERE ${whereclause} GROUP BY b.id")
  trace "[getbatchdetails] batch=${batch}"

  if [ -n "${batch}" ]; then
    local tx_id
    local outputs

    tx_id=$(echo "${batch}" | cut -d '|' -f2)
    trace "[getbatchdetails] tx_id=${tx_id}"
    if [ -n "${tx_id}" ]; then
      # Using txid
      outerclause="AND r.tx_id=${tx_id}"
      
      tx=$(sql "SELECT '\"txid\":\"' || txid || '\",\"hash\":\"' || hash || '\",\"details\":{\"firstseen\":' || timereceived || ',\"size\":' || size || ',\"vsize\":' || vsize || ',\"replaceable\":' || is_replaceable || ',\"fee\":' || fee || '}' FROM tx WHERE id=${tx_id}")
    else
      # null txid
      outerclause="AND r.tx_id IS NULL"
    fi

    batcher_id=$(echo "${batch}" | cut -d '|' -f1)
    outputs=$(sql "SELECT '{\"outputId\":' || id || ',\"outputLabel\":\"' || COALESCE(label, '') || '\",\"address\":\"' || address || '\",\"amount\":' || amount || ',\"addedTimestamp\":\"' || inserted_ts || '\"}' FROM recipient r WHERE batcher_id=${batcher_id} ${outerclause}")

    local output
    local IFS=$'\n'
    for output in ${outputs}
    do
      if [ -n "${outputsjson}" ]; then
        outputsjson="${outputsjson},${output}"
      else
        outputsjson="${output}"
      fi
    done

    batch=$(echo "${batch}" | cut -d '|' -f3)

    response='{"result":'${batch}
    if [ -n "${tx}" ]; then
      response=${response}','${tx}
    else
      response=${response}',"txid":null,"hash":null'
    fi
    response=${response}',"outputs":['${outputsjson}']},"error":null}'
  else
    response='{"result":null,"error":{"code":-32700,"message":"batch not found or no corresponding txid","data":'${request}'}}'
  fi

  echo "${response}"

}

# curl localhost:8888/listbatchers | jq
# curl -d '{}' localhost:8888/getbatcher | jq
# curl -d '{}' localhost:8888/getbatchdetails | jq
# curl -d '{"outputLabel":"test002","address":"1abd","amount":0.0002}' localhost:8888/addtobatch | jq
# curl -d '{}' localhost:8888/batchspend | jq
# curl -d '{"outputId":1}' localhost:8888/removefrombatch | jq

# curl -d '{"batcherLabel":"lowfees","confTarget":32}' localhost:8888/createbatcher | jq
# curl localhost:8888/listbatchers | jq

# curl -d '{"batcherLabel":"lowfees"}' localhost:8888/getbatcher | jq
# curl -d '{"batcherLabel":"lowfees"}' localhost:8888/getbatchdetails | jq
# curl -d '{"batcherLabel":"lowfees","outputLabel":"test002","address":"1abd","amount":0.0002}' localhost:8888/addtobatch | jq
# curl -d '{"batcherLabel":"lowfees"}' localhost:8888/batchspend | jq
# curl -d '{"batcherLabel":"lowfees","outputId":9}' localhost:8888/removefrombatch | jq
