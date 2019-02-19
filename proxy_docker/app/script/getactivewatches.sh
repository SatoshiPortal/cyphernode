#!/bin/sh

. ./trace.sh
. ./sql.sh

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
