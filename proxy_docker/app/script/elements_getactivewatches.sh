#!/bin/sh

. ./trace.sh
. ./sql.sh

elements_get_txns_by_watchlabel(){
  trace "Entering elements_get_txns_by_watchlabel() for label ${1}..."
  local label_txns
  query=$(cat <<-HERE
	SELECT w32.label, w.address, tx.txid, tx.confirmations,tx.blockheight, wtxn.vout, wtxn.amount, tx.blockhash, tx.blocktime, tx.timereceived 
	FROM elements_watching_by_pub32 as w32
	INNER JOIN elements_watching AS w ON w32.id = w.watching_by_pub32_id
	INNER JOIN elements_watching_tx AS wtxn ON w.id = wtxn.watching_id
	INNER JOIN elements_tx AS tx ON wtxn.tx_id = tx.id
	WHERE w32.label="$1"
	LIMIT 0,${2-10}
HERE
  )
  label_txns=$(sql "$query")
  returncode=$?
  trace_rc ${returncode}
  label_txns_json=$(echo "$label_txns" | jq -Rcsn '
  {"label_txns":
    [inputs
     | . / "\n"
     | (.[] | select(length > 0) | . / "|") as $input
     | {"label": $input[0], "address": $input[1], "txid": $input[2], "confirmations": $input[3], "blockheight": $input[4], "v_out": $input[5], "amount": $input[6], "blockhash": $input[7], "blocktime": $input[8], "timereceived": $input[9]}
    ]
  }
  ')
  echo "$label_txns_json"
  return ${returncode}
}
elements_get_unused_addresses_by_watchlabel(){
  trace "Entering elements_get_unused_addresses_by_watchlabel() for label ${1}..."
  local label_unused_addrs
  query=$(cat <<-HERE
        SELECT w32.id, w32.label, w32.pub32, w.pub32_index, w.address
        FROM elements_watching as w
        INNER JOIN elements_watching_by_pub32 AS w32 ON w.watching_by_pub32_id = w32.id
        WHERE w32.label="$1"
        AND NOT EXISTS (
                SELECT 1 FROM elements_watching_tx WHERE watching_id = w.id
        )
        ORDER BY w.pub32_index ASC
	LIMIT 0,${2-10}
HERE
  )
  label_unused_addrs=$(sql "$query")
  returncode=$?
  trace_rc ${returncode}
  label_unused_addrs_json=$(echo "$label_unused_addrs" | jq -Rcsn '
  {"label_unused_addresses":
    [inputs
     | . / "\n"
     | (.[] | select(length > 0) | . / "|") as $input
     | {"pub32_watch_id": $input[0], "pub32_label": $input[1], "pub32" : $input[2], "address_pub32_index": $input[3], "address": $input[4]}
    ]
  }
  ')
  echo "$label_unused_addrs_json"
  return ${returncode}
}

elements_getactivewatches() {
  trace "Entering elements_getactivewatches()..."

  local watches
  # Let's build the string directly with sqlite instead of manipulating multiple strings afterwards, it's faster.
  # {"id":"${id}","address":"${address}","imported":"${imported}","unconfirmedCallbackURL":"${cb0conf_url}","confirmedCallbackURL":"${cb1conf_url}","watching_since":"${timestamp}"}
  watches=$(sql "SELECT '{\"id\":' || id || ',\"address\":\"' || address || '\",\"imported\":' || imported || ',\"unconfirmedCallbackURL\":\"' || COALESCE(callback0conf, '') || '\",\"confirmedCallbackURL\":\"' || COALESCE(callback1conf, '') || '\",\"watching_since\":\"' || inserted_ts || '\"}' FROM elements_watching WHERE watching AND NOT calledback1conf")
  returncode=$?
  trace_rc ${returncode}

  local notfirst=false

  echo -n "{\"watches\":["

  local IFS=$'\n'
  for row in ${watches}
  do
    if ${notfirst}; then
      echo ","
    else
      notfirst=true
    fi
    trace "[elements_getactivewatches] row=${row}"

    echo -n "${row}"
  done

  echo "]}"

  return ${returncode}
}

elements_getactivewatchesbyxpub() {
  trace "Entering elements_getactivewatchesbyxpub()..."

  local xpub=${1}
  local returncode

  elements_getactivewatchesxpub "pub32" ${xpub}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

elements_getactivewatchesbylabel() {
  trace "Entering elements_getactivewatchesbylabel()..."

  local label=${1}
  local returncode

  elements_getactivewatchesxpub "label" ${label}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

elements_getactivewatchesxpub() {
  trace "Entering elements_getactivewatchesxpub()..."

  local where=${1}
  trace "[elements_getactivewatchesxpub] where=${where}"
  local value=${2}
  trace "[elements_getactivewatchesxpub] value=${value}"
  local watches

  # Let's build the string directly with sqlite instead of manipulating multiple strings afterwards, it's faster.
  # {"id":"${id}","address":"${address}","imported":"${imported}","unconfirmedCallbackURL":"${cb0conf_url}","confirmedCallbackURL":"${cb1conf_url}","watching_since":"${timestamp}","derivation_path":"${derivation_path}","pub32_index":"${pub32_index}"}
  watches=$(sql "SELECT '{\"id\":' || w.id || ',\"address\":\"' || address || '\",\"imported\":' || imported || ',\"unconfirmedCallbackURL\":\"' || COALESCE(w.callback0conf, '') || '\",\"confirmedCallbackURL\":\"' || COALESCE(w.callback1conf, '') || '\",\"watching_since\":\"' || w.inserted_ts || '\",\"derivation_path\":\"' || derivation_path || '\",\"pub32_index\":' || pub32_index || '}' FROM elements_watching w, elements_watching_by_pub32 w32 WHERE watching_by_pub32_id = w32.id AND ${where} = \"${value}\" AND w.watching AND NOT calledback1conf")
  returncode=$?
  trace_rc ${returncode}

  local notfirst=false

  echo -n "{\"watches\":["

  local IFS=$'\n'
  for row in ${watches}
  do
    if ${notfirst}; then
      echo ","
    else
      notfirst=true
    fi
    trace "[elements_getactivewatchesxpub] row=${row}"

    echo -n "${row}"
  done

  echo "]}"

  return ${returncode}
}

elements_getactivexpubwatches() {
  trace "Entering elements_getactivexpubwatches()..."

  local watches
  # Let's build the string directly with sqlite instead of manipulating multiple strings afterwards, it's faster.
  # {"id":"${id}","pub32":"${pub32}","label":"${label}","derivation_path":"${derivation_path}","last_imported_n":${last_imported_n},"unconfirmedCallbackURL":"${cb0conf_url}","confirmedCallbackURL":"${cb1conf_url}","watching_since":"${timestamp}"}
  watches=$(sql "SELECT '{\"id\":' || id || ',\"pub32\":\"' || pub32 || '\",\"label\":\"' || label || '\",\"derivation_path\":\"' || derivation_path || '\",\"last_imported_n\":' || last_imported_n || ',\"unconfirmedCallbackURL\":\"' || COALESCE(callback0conf, '') || '\",\"confirmedCallbackURL\":\"' || COALESCE(callback1conf, '') || '\",\"watching_since\":\"' || inserted_ts || '\"}' FROM elements_watching_by_pub32 WHERE watching")
  returncode=$?
  trace_rc ${returncode}

  local notfirst=false

  echo -n "{\"watches\":["

  local IFS=$'\n'
  for row in ${watches}
  do
    if ${notfirst}; then
      echo ","
    else
      notfirst=true
    fi
    trace "[getactivexpubwatches] row=${row}"

    echo -n "${row}"
  done

  echo "]}"

  return ${returncode}
}
