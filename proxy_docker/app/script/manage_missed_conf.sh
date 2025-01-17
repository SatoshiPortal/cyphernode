#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./importaddress.sh
. ./confirmation.sh

manage_not_imported() {
  # When we tried to import watched addresses in the watching node,
  # if it didn't succeed, we try again here.

  trace "[Entering manage_not_imported()]"

  local watches=$(sql 'SELECT address, label FROM watching WHERE watching AND NOT imported')
  trace "[manage_not_imported] watches=${watches}"

  local result
  local returncode
  local IFS="
"
  for row in ${watches}
  do
    address=$(echo "${row}" | cut -d '|' -f1)
    label=$(echo "${row}" | cut -d '|' -f2)
    result=$(importaddress_rpc "${address}" "${label}")
    returncode=$?
    trace_rc ${returncode}
    if [ "${returncode}" -eq 0 ]; then
      sql "UPDATE watching SET imported=true WHERE address='${address}'"
    fi
  done

  return 0
}

manage_missed_conf() {
  # Maybe we missed 0-conf or 1-conf watched txs, because we were down or no network or
  # whatever, so we look at what might be missed and do confirmations.

  # The strategy here: get the list of watched addresses, see if they received something on the Bitcoin node,
  # and for each ones that received something after the watching timestamp, we kinda missed them...

  trace "[Entering manage_missed_conf()]"

  local watches=$(sql "SELECT DISTINCT address FROM watching w LEFT JOIN watching_tx ON w.id = watching_id LEFT JOIN tx t ON t.id = tx_id WHERE watching AND imported ORDER BY address")
  trace "[manage_missed_conf] watches=${watches}"
  if [ ${#watches} -eq 0 ]; then
    trace "[manage_missed_conf] Nothing missed!"
    return 0
  fi

  local received_watches
  local data

  for address in ${watches}
  do
    if [ -n "${data}" ]; then
      data=${data}','
    fi
    data=${data}'{"id":"'${address}'","method":"listreceivedbyaddress","params":[0,false,true,"'${address}'"]}'
  done
  received_watches=$(send_batch_to_bitcoin_node "${WATCHER_BTC_NODE_RPC_URL}/${WATCHER_BTC_NODE_DEFAULT_WALLET}" "${WATCHER_BTC_NODE_RPC_CFG}" "[${data}]")
  trace "[manage_missed_conf] received_watches=${received_watches}"
  # received_watches=[{"result":[],"error":null,"id":"bcrt1q05laru93h7qkf8v0ujaezzsgvakh0t6ytdz8xk"},{"result":[],"error":null,"id":"bcrt1q597re8ayjlls2saz0ypxfks4f22r38zmynwqsx"},{"result":[],"error":null,"id":"bcrt1q65pc8vqznl2l5wk4fd800l5lv0w9dml2c6rws6"},{"result":[{"involvesWatchonly":true,"address":"bcrt1q7xun0gcgt4hu8xtc8e7ttzkw64sp6yun4pzumk","amount":0.00010000,"confirmations":1,"label":"missed1conftest","txids":["05f1912ebdf1538964c7f0d4fb0643e7e35c21cba82e080518c11bebec1aeec4"]}],"error":null,"id":"bcrt1q7xun0gcgt4hu8xtc8e7ttzkw64sp6yun4pzumk"},{"result":[],"error":null,"id":"bcrt1qe3x9zv59xeepgqzgsyhn6s7n3ewkck7wlnmv4f"},{"result":[],"error":null,"id":"bcrt1qegp66u24qjt5m8e7r8z7c243csv7x9e2w55j00"},{"result":[],"error":null,"id":"bcrt1qfhkpv4mghzps09g6t2f693yhh6qqvhw0hyq0yz"},{"result":[],"error":null,"id":"bcrt1qg7hruwvec90fe3ku7unqgccgu6r6mkwrcm7lzj"},{"result":[{"involvesWatchonly":true,"address":"bcrt1qpzwcuhl0tmen8wu26rfyw4eaeq9ku3xqva85ft","amount":0.00010000,"confirmations":3,"label":"missed1conftest","txids":["fb045d4bae557fbae17d4338b15bdab90deff46c1b22c8dd0d34e2100f081d8e"]}],"error":null,"id":"bcrt1qpzwcuhl0tmen8wu26rfyw4eaeq9ku3xqva85ft"},{"result":[],"error":null,"id":"bcrt1qq38fekxvxgn3cw859ps3alf4acugm3h8svzshy"},{"result":[],"error":null,"id":"bcrt1qr8ur0fdc3h9yeqjverc8x2lxjkyp6mlfg0ht03"},{"result":[{"involvesWatchonly":true,"address":"bcrt1qt09cttrcpdfcfr6wltkzdv48ep7h3acux6v8tl","amount":0.00010000,"confirmations":5,"label":"missed1conftest","txids":["4e859d9ce6c173d8373b2222127687bb697311161ec36deff2f1a12282c88b27"]}],"error":null,"id":"bcrt1qt09cttrcpdfcfr6wltkzdv48ep7h3acux6v8tl"},{"result":[{"involvesWatchonly":true,"address":"bcrt1qwdpehjzu6sszp7zgdsud7se6trv2rt35szrcqz","amount":0.00010000,"confirmations":8,"label":"missed1conftest","txids":["bab2adb187ed0d04c8ca0d93f6c94eb2a5c7cccef39d9fb00bd9dab92210f68a"]}],"error":null,"id":"bcrt1qwdpehjzu6sszp7zgdsud7se6trv2rt35szrcqz"},{"result":null,"error":{"code":-4,"message":"address_filter parameter was invalid"},"id":"tb1q7g0zneqlww82vafshwgf5rz6mhgj2lkpkkt08x"},{"result":null,"error":{"code":-4,"message":"address_filter parameter was invalid"},"id":"tb1qpf55tg76lurah3z67d3tk93tc2yzmntspsjqnc"},{"result":null,"error":{"code":-4,"message":"address_filter parameter was invalid"},"id":"tb1qx5jwlzjscz2k6cfse8tn4pdrlye8es7epz5msc"}]

  received_watches=$(echo "${received_watches}" | jq -Mc '.[] | select(.result != [] and .result != null) | .result[0]')
  trace "[manage_missed_conf] received_watches=${received_watches}"

  local received_watch
  local confirmations
  local watching
  local latesttxid
  local tx
  local blocktime
  local data
  local result
  local returncode
  local row
  local address
  local inserted_ts
  local calledback0conf
  local txid
  local txids
  local IFS="
"
  for received_watch in ${received_watches}
  do
    address=$(echo "${received_watch}" | jq -r '.address')
    watching=$(sql "SELECT address, inserted_ts, calledback0conf FROM watching WHERE address='${address}'")
    trace "[manage_missed_conf] watching=${watching}"
    if [ ${#watching} -eq 0 ]; then
      trace "[manage_missed_conf] Nothing missed!"
      continue
    fi

    inserted_ts=$(date -d "$(echo "${watching}" | cut -d '|' -f2)" +%s)
    trace "[manage_missed_conf] inserted_ts=${inserted_ts}"
    calledback0conf=$(echo "${watching}" | cut -d '|' -f3)
    trace "[manage_missed_conf] calledback0conf=${calledback0conf}"
    confirmations=$(echo "${received_watch}" | jq -r ".confirmations")
    trace "[manage_missed_conf] confirmations=${confirmations}"

    if [ "${confirmations}" -eq "0" ] && [ "${calledback0conf}" = "t" ]; then
      # 0-conf and calledback0conf is true, so let's skip this one
      trace "[manage_missed_conf] Nothing missed!"
    else
      # 0-conf and calledback0conf false, let's call confirmation
      # or
      # 1-conf and calledback1conf false, let's call confirmation
      trace "[manage_missed_conf] We got something to check..."

      latesttxid=$(echo "${received_watch}" | jq -r ".txids | last")
      trace "[manage_missed_conf] latesttxid=${latesttxid}"
      data="{\"method\":\"gettransaction\",\"params\":[\"${latesttxid}\",true,true]}"
      trace "[manage_missed_conf] calling method=${data}"

      tx=$(send_to_watcher_node "${data}")

      blocktime=$(echo "${tx}" | jq '.result.blocktime')
      txtime=$(echo "${tx}" | jq '.result.time')

      trace "[manage_missed_conf] blocktime=${blocktime}"
      trace "[manage_missed_conf] txtime=${txtime}"
      trace "[manage_missed_conf] inserted_ts=${inserted_ts}"
      trace "[manage_missed_conf] confirmations=${confirmations}"

      if [ "${txtime}" -ge "${inserted_ts}" ]; then
        # Broadcast or mined after watch, we missed it!
        trace "[manage_missed_conf] Broadcast or mined after watch, we missed it!"
        # We skip the callbacks because do_callbacks is called right after in
        # requesthandler.executecallbacks (where we're from)
        confirmation "$(echo "${tx}" | jq -Mc '.result' | base64 -w 0)" "true"
      fi
    fi
  done

  return 0
}

case "${0}" in *manage_missed_conf.sh) manage_not_imported "$@"; manage_missed_conf "$@";; esac
