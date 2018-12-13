#!/bin/sh

monitoring_count() {
  # type label count prefix
  monitoring_fireAndForget "c" $1 $2 $3
}

monitoring_gauge() {
  # type label count prefix
  monitoring_fireAndForget "g" $1 $2 $3
}

monitoring_fireAndForget() {
  if [[ $FEATURE_GRAFANA == true ]]; then
    local type=$1
    local label=$2
    local count=$3
    local prefix=$4

    if [[ ! $count ]]; then
      count=1
    fi

    if [[ $label ]]; then
      local entry="${label}:${count}|${type}"
      if [[ $prefix ]]; then
        entry="${prefix}.${entry}"
      fi
      echo ${entry} | socat -t 0 - UDP:grafana:8125
    fi
  fi
}

monitor_command() {
  local prefix=$1; shift
  local label=$1; shift

  "$@"
  local return_code=$?

  monitoring_count $label 1 $prefix
  if [[ $return_code -ne 0 ]]; then
    monitoring_count "error.${label}" 1 $prefix
  fi

  return $return_code
}