#!/bin/sh

. ./trace.sh
. ./sql.sh

get_txns_by_watchlabel(){
  trace "Entering get_txns_by_watchlabel()..."
  local label_txns
  $sql = "SELECT w32.label, w.address, wtxn.txn_id, wtxn.v_out, wtxn.amount FROM watching_by_pub32 as w32 INNER JOIN watching ON w32.id = w.watching_by_pub32_id INNER JOIN watching_tx as wtxn ON w.id = wtxn.watching_id WHERE w32.label={$1}" 
  $label_txns = $(sql "$sql")
  returncode=$?
  trace_rc ${returncode}
  $label_txns_json = jq -Rsn '
  {"label_txns":
    [inputs
     | . / "\n"
     | (.[] | select(length > 0) | . / "|") as $input
     | {"label": $input[0], "address": $input[1], "txn_id": "$input[2], "v_out": $input[3], "amount" : $input[4]}]}
  ' <$($label_txns)
  return $label_txns_json
}
get_unused_addresses_by_watchlabel(){
  trace "Entering get_unused_addresses_by_watchlabel()..."
  local label_txns
  $sql = "SELECT w.watching_by_pub32_id, w.pub32_index, w.address FROM watching as w WHERE w.id NOT IN (SELECT watching_id FROM watching_tx) WHERE w.label=${1}" 
  $label_txns = $(sql "$sql")
  returncode=$?
  trace_rc ${returncode}
  $label_txns_json = jq -Rsn '
  {"label_unused_addresses":
    [inputs
     | . / "\n"
     | (.[] | select(length > 0) | . / "|") as $input
     | {"pub32_watch_id": $input[0], "address_pub32_index": $input[1], "address": "$input[2] }]}
  ' <$($label_txns)
  return $label_txns_json
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
