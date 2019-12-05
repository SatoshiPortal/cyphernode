#!/bin/sh

. ./trace.sh
. ./sql.sh

get_txns_by_watchlabel(){
  trace "Entering get_txns_by_watchlabel()..."
  local label_txns
  $query=<<HERE
	SELECT w32.label, w.address, tx.txid, tx.confirmations,tx.blockheight, wtxn.v_out, wtxn.amount
	FROM watching_by_pub32 as w32
	INNER JOIN watching ON w32.id = w.watching_by_pub32_id
	INNER JOIN watching_tx as wtxn ON w.id = wtxn.watching_id
	INNER JOIN tx as tx ON wtxn.tx_id = tx.id
	WHERE w32.label="$1"
HERE
  $label_txns=$(sql "$query")
  returncode=$?
  trace_rc ${returncode}
  $label_txns_json = $(echo "$label_txns" | jq -Rcsn '
  {"label_txns":
    [inputs
     | . / "\n"
     | (.[] | select(length > 0) | . / "|") as $input
     | {"label": $input[0], "address": $input[1], "txid": "$input[2], "confirmations": $input[3], "blockheight" : $input[4], "v_out":$input[5], "amount": $input[6]}
    ]
  }')
  echo "$label_txns_json"
  return ${returncode}
}
get_unused_addresses_by_watchlabel(){
  trace "Entering get_unused_addresses_by_watchlabel()... $1"
  local label_unused_addrs
  query=$(cat <<-HERE
        SELECT w32.id, w32.label, w32.pub32, w.pub32_index, w.address
        FROM watching as w
        INNER JOIN watching_by_pub32 AS w32 ON w.watching_by_pub32_id = w32.id
        WHERE w.id NOT IN (
                SELECT watching_id FROM watching_tx
        )
        AND w32.label="$1"
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
     | {"pub32_watch_id": $input[0], "pub32_label": $input[1], "pub32" : $input[2], "address_pub32_index": $input[3], "address": $input[4]
    ]
  }
  ')
  echo "$label_unused_addrs_json"
  return ${returncode}
}
getactivewatches() {
  trace "Entering getactivewatches()..."

  local watches
  # Let's build the string directly with sqlite instead of manipulating multiple strings afterwards, it's faster.
  # {"id":"${id}","address":"${address}","imported":"${imported}","unconfirmedCallbackURL":"${cb0conf_url}","confirmedCallbackURL":"${cb1conf_url}","watching_since":"${timestamp}"}
  watches=$(sql "SELECT '{\"id\":\"' || id || '\",\"address\":\"' || address || '\",\"imported\":\"' || imported || '\",\"unconfirmedCallbackURL\":\"' || callback0conf || '\",\"confirmedCallbackURL\":\"' || callback1conf || '\",\"watching_since\":\"' || inserted_ts || '\"}' FROM watching WHERE watching AND NOT calledback1conf")
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
    trace "[getactivewatches] row=${row}"

    echo -n "${row}"
  done

  echo "]}"

  return ${returncode}
}

getactivewatchesbyxpub() {
  trace "Entering getactivewatchesbyxpub()..."

  local xpub=${1}
  local returncode

  getactivewatchesxpub "pub32" ${xpub}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

getactivewatchesbylabel() {
  trace "Entering getactivewatchesbylabel()..."

  local label=${1}
  local returncode

  getactivewatchesxpub "label" ${label}
  returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

getactivewatchesxpub() {
  trace "Entering getactivewatchesxpub()..."

  local where=${1}
  trace "[getactivewatchesxpub] where=${where}"
  local value=${2}
  trace "[getactivewatchesxpub] value=${value}"
  local watches

  # Let's build the string directly with sqlite instead of manipulating multiple strings afterwards, it's faster.
  # {"id":"${id}","address":"${address}","imported":"${imported}","unconfirmedCallbackURL":"${cb0conf_url}","confirmedCallbackURL":"${cb1conf_url}","watching_since":"${timestamp}","derivation_path":"${derivation_path}","pub32_index":"${pub32_index}"}
  watches=$(sql "SELECT '{\"id\":\"' || w.id || '\",\"address\":\"' || address || '\",\"imported\":\"' || imported || '\",\"unconfirmedCallbackURL\":\"' || w.callback0conf || '\",\"confirmedCallbackURL\":\"' || w.callback1conf || '\",\"watching_since\":\"' || w.inserted_ts || '\",\"derivation_path\":\"' || derivation_path || '\",\"pub32_index\":\"' || pub32_index || '\"}' FROM watching w, watching_by_pub32 w32 WHERE watching_by_pub32_id = w32.id AND ${where} = \"${value}\" AND w.watching AND NOT calledback1conf")
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
    trace "[getactivewatchesxpub] row=${row}"

    echo -n "${row}"
  done

  echo "]}"

  return ${returncode}
}

getactivexpubwatches() {
  trace "Entering getactivexpubwatches()..."

  local watches
  # Let's build the string directly with sqlite instead of manipulating multiple strings afterwards, it's faster.
  # {"id":"${id}","pub32":"${pub32}","label":"${label}","derivation_path":"${derivation_path}","last_imported_n":${last_imported_n},"unconfirmedCallbackURL":"${cb0conf_url}","confirmedCallbackURL":"${cb1conf_url}","watching_since":"${timestamp}"}
  watches=$(sql "SELECT '{\"id\":\"' || id || '\",\"pub32\":\"' || pub32 || '\",\"label\":\"' || label || '\",\"derivation_path\":\"' || derivation_path || '\",\"last_imported_n\":' || last_imported_n || ',\"unconfirmedCallbackURL\":\"' || callback0conf || '\",\"confirmedCallbackURL\":\"' || callback1conf || '\",\"watching_since\":\"' || inserted_ts || '\"}' FROM watching_by_pub32 WHERE watching")
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
