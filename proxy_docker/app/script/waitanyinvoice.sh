#!/bin/sh

. ./trace.sh
. ./sql.sh
. ./callbacks_job.sh

ln_waitanyinvoice() {
  trace "Entering ln_waitanyinvoice()..."

  local lastpay_index=${1}
  trace "[ln_waitanyinvoice] lastpay_index=${lastpay_index}"
  local returncode
  local result
  local bolt11
  local pay_index
  local row
  local id
  local callback_url

  #{
  #  "label": "Duvapk2OWvlmL3kf5GyDF",
  #  "bolt11": "lnbc1546230n1pwzanfspp5t5jr3rsjkh37986nzkta8kk0yyzam833l5e4an5nu6cyhjcjluwqdq9u2d2zxqr3jscqp2rzjqt04ll5ft3mcuy8hws4xcku2pnhma9r9mavtjtadawyrw5kgzp7g7zr745qq3mcqqyqqqqlgqqqqqzsqpclrjg6vtg4cmqj46przdgwp6rk0xmzfa7ga3wnm4h4evzxy3z32aqw77av65cz2mgcf02dak3vl25epq90dw289zz9x87dyjy6nqvchsq6p8nmj",
  #  "payment_hash": "5d24388e12b5e3e29f531597d3dacf2105dd9e31fd335ece93e6b04bcb12ff1c",
  #  "msatoshi": 154623000,
  #  "status": "paid",
  #  "pay_index": 12,
  #  "msatoshi_received": 154623000,
  #  "paid_at": 1546571113,
  #  "description": "...",
  #  "expires_at": 1546589056
  #},

  result=$(./lightning-cli waitanyinvoice ${lastpay_index})
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_waitanyinvoice] result=${result}"

  if [ "${returncode}" -eq "0" ]; then
    bolt11=$(echo "${result}" | jq ".bolt11" | tr -d '"')
    pay_index=$(echo "${result}" | jq ".pay_index" | tr -d '"')
    msatoshi_received=$(echo "${result}" | jq ".msatoshi_received" | tr -d '"')
    status=$(echo "${result}" | jq ".status" | tr -d '"')
    paid_at=$(echo "${result}" | jq ".paid_at" | tr -d '"')

    sql "UPDATE ln_invoice SET status=\"${status}\", pay_index=${pay_index}, msatoshi_received=${msatoshi_received}, paid_at=${paid_at} WHERE bolt11=\"${bolt11}\""
    row=$(sql "SELECT id, label, bolt11, callback_url, payment_hash, msatoshi, status, pay_index, msatoshi_received, paid_at, description, expires_at FROM ln_invoice WHERE NOT calledback AND bolt11=\"${bolt11}\"")

    if [ -n "${row}" ]; then
      ln_manage_callback ${row}
    fi

    sql "UPDATE cyphernode_props SET value="${pay_index}" WHERE property=\"pay_index\""
  fi
}

while :
do
  pay_index=$(sql "SELECT value FROM cyphernode_props WHERE property='pay_index'")
  trace "[waitanyinvoice] pay_index=${pay_index}"
  ln_waitanyinvoice ${pay_index}
  sleep 5
done
