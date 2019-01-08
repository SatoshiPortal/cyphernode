#!/bin/sh

. ./trace.sh

ln_create_invoice()
{
  trace "Entering ln_create_invoice()..."

  local result

  local request=${1}
  local msatoshi=$(echo "${request}" | jq ".msatoshi" | tr -d '"')
  trace "[ln_create_invoice] msatoshi=${msatoshi}"
  local label=$(echo "${request}" | jq ".label")
  trace "[ln_create_invoice] label=${label}"
  local description=$(echo "${request}" | jq ".description")
  trace "[ln_create_invoice] description=${description}"
  local expiry=$(echo "${request}" | jq ".expiry" | tr -d '"')
  trace "[ln_create_invoice] expiry=${expiry}"
  local callback_url=$(echo "${request}" | jq ".callback_url" | tr -d '"')
  trace "[ln_create_invoice] callback_url=${callback_url}"

  #/proxy $ ./lightning-cli invoice 10000 "t1" "t1d" 60
  #{
  #  "payment_hash": "a74e6cccb06e26bcddc32c43674f9c3cf6b018a4cb9e9ff7f835cc59b091ae06",
  #  "expires_at": 1546648644,
  #  "bolt11": "lnbc100n1pwzllqgpp55a8xen9sdcntehwr93pkwnuu8nmtqx9yew0flalcxhx9nvy34crqdq9wsckgxqzpucqp2rzjqt04ll5ft3mcuy8hws4xcku2pnhma9r9mavtjtadawyrw5kgzp7g7zr745qq3mcqqyqqqqlgqqqqqzsqpcr85k33shzaxscpj29fadmjmfej6y2p380x9w4kxydqpxq87l6lshy69fry9q2yrtu037nt44x77uhzkdyn8043n5yj8tqgluvmcl69cquaxr68"
  #}

  result=$(./lightning-cli invoice ${msatoshi} "${label}" "${description}" ${expiry})
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_create_invoice] result=${result}"

  local bolt11
  bolt11=$(echo ${result} | jq ".bolt11" | tr -d '"')
  trace "[ln_create_invoice] bolt11=${bolt11}"
  sql "INSERT OR IGNORE INTO ln_invoice (bolt11, callback_url) VALUES (\"${bolt11}\", \"${callback_url}\")"
  trace_rc $?

  echo "${result}"

  return ${returncode}
}

ln_getinfo()
{
  trace "Entering ln_get_info()..."

  local result

  result=$(./lightning-cli getinfo)
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_getinfo] result=${result}"

  echo "${result}"

  return ${returncode}
}

ln_pay() {
  trace "Entering ln_pay()..."

  local result

  local request=${1}
  local bolt11=$(echo "${request}" | jq ".bolt11" | tr -d '"')
  trace "[ln_pay] bolt11=${bolt11}"
  local expected_msatoshi=$(echo "${request}" | jq ".expected_msatoshi")
  trace "[ln_pay] expected_msatoshi=${expected_msatoshi}"
  local expected_description=$(echo "${request}" | jq ".expected_description")
  trace "[ln_pay] expected_description=${expected_description}"

  result=$(./lightning-cli decodepay ${bolt11})

  local invoice_msatoshi=$(echo "${result}" | jq ".msatoshi")
  trace "[ln_pay] invoice_msatoshi=${invoice_msatoshi}"
  local invoice_description=$(echo "${result}" | jq ".description")
  trace "[ln_pay] invoice_description=${invoice_description}"

  if [ "${expected_msatoshi}" != "${invoice_msatoshi}" ]; then
    result="{\"result\":\"error\",\"expected_msatoshi\":${expected_msatoshi},\"invoice_msatoshi\":${invoice_msatoshi}}"
    returncode=1
  elif [ "${expected_description}" != "${invoice_description}" ]; then
    result="{\"result\":\"error\",\"expected_description\":${expected_description},\"invoice_description\":${invoice_description}}"
    returncode=1
  else
    result=$(./lightning-cli pay ${bolt11})
    returncode=$?
    trace_rc ${returncode}
  fi
  trace "[ln_pay] result=${result}"

  echo "${result}"

  return ${returncode}
}

ln_newaddr()
{
  trace "Entering ln_newaddr()..."

  local result

  call_lightningd newaddr
  result=$(./lightning-cli newaddr)
  returncode=$?
  trace_rc ${returncode}
  trace "[ln_newaddr] result=${result}"

  echo "${result}"

  return ${returncode}
}

case "${0}" in *call_lightningd.sh) call_lightningd $@;; esac
