#!/bin/sh

. ./trace.sh
. ./sql.sh

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

  bolt11=$(echo ${result} | jq ".bolt11" | tr -d '"')
  pay_index=$(echo ${result} | jq ".pay_index" | tr -d '"')

  row=$(sql "SELECT id, callback_url FROM ln_invoice WHERE NOT calledback AND bolt11=\"${bolt11}\"")

  id=$(echo ${row} | cut -d '|' -f1)
  callback_url=$(echo ${row} | cut -d '|' -f2)
  if [ -z "${callback_url}" ]; then
    # No callback url provided for that invoice
    sql "UPDATE ln_invoice SET calledback=1 WHERE id=\"${id}\""
    trace_rc $?
    return
  fi

  ln_payment_callback ${callback_url}
  returncode=$?
  trace_rc ${returncode}
  if [ "${returncode}" -eq 0 ]; then
    sql "UPDATE ln_invoice SET calledback=1 WHERE id=\"${id}\""
    trace_rc $?
  else
    trace "[ln_waitanyinvoice] callback failed: ${callback_url}"
    sql "UPDATE ln_invoice SET callback_failed=1 WHERE id=\"${id}\""
    trace_rc $?
  fi

  sql "UPDATE cyphernode_props SET value="${pay_index}" WHERE property=\"pay_index\""

}

ln_payment_callback() {
  trace "Entering ln_payment_callback()..."

  local url=${1}

  trace "[ln_payment_callback] curl ${url}"
  curl -H "X-Forwarded-Proto: https" ${url}
  local returncode=$?
  trace_rc ${returncode}

  return ${returncode}
}

while :
do
  pay_index=$(sql "SELECT value FROM cyphernode_props WHERE property='pay_index'")
  trace "[waitanyinvoice] pay_index=${pay_index}"
  ln_waitanyinvoice ${pay_index}
  sleep 1
done
