#!/bin/sh

. ./trace.sh
. ./importaddress.sh
. ./sql.sh
. ./sendtobitcoinnode.sh

watchrequest()
{
  trace "Entering watchrequest()..."

  local returncode
  local request=${1}
  local address=$(echo "${request}" | jq ".address" | tr -d '"')
  local cb0conf_url=$(echo "${request}" | jq ".unconfirmedCallbackURL" | tr -d '"')
  local cb1conf_url=$(echo "${request}" | jq ".confirmedCallbackURL" | tr -d '"')
  local imported
  local inserted
  local id_inserted
  local result
  trace "[watchrequest] Watch request on address (${address}), cb 0-conf (${cb0conf_url}), cb 1-conf (${cb1conf_url})"

  result=$(importaddress_rpc "${address}")
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    imported=1
  else
    imported=0
  fi

  sql "INSERT OR IGNORE INTO watching (address, watching, callback0conf, callback1conf, imported) VALUES (\"${address}\", 1, \"${cb0conf_url}\", \"${cb1conf_url}\", ${imported})"
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    inserted=1
    id_inserted=$(sql "SELECT id FROM watching WHERE address='${address}'")
    trace "[watchrequest] id_inserted: ${id_inserted}"
  else
    inserted=0
  fi

  local fees2blocks
  local fees6blocks
  local fees36blocks
  local fees144blocks
  fees2blocks=$(getestimatesmartfee 2)
  trace_rc $?
  fees6blocks=$(getestimatesmartfee 6)
  trace_rc $?
  fees36blocks=$(getestimatesmartfee 36)
  trace_rc $?
  fees144blocks=$(getestimatesmartfee 144)
  trace_rc $?

  local data="{\"id\":\"${id_inserted}\",
  \"event\":\"watch\",
  \"imported\":\"${imported}\",
  \"inserted\":\"${inserted}\",
  \"address\":\"${address}\",
  \"unconfirmedCallbackURL\":\"${cb0conf_url}\",
  \"confirmedCallbackURL\":\"${cb1conf_url}\",
  \"estimatesmartfee2blocks\":\"${fees2blocks}\",
  \"estimatesmartfee6blocks\":\"${fees6blocks}\",
  \"estimatesmartfee36blocks\":\"${fees36blocks}\",
  \"estimatesmartfee144blocks\":\"${fees144blocks}\"}"
  trace "[watchrequest] responding=${data}"

  echo "${data}"

  return ${returncode}
}

case "${0}" in *watchrequest.sh) watchrequest $@;; esac
