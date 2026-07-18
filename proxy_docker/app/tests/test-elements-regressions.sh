#!/bin/sh

set -u

TRACING=

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../script" && pwd)
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "${TEST_TMPDIR}"' EXIT

fail() {
  echo "not ok - $1" >&2
  exit 1
}

pass() {
  echo "ok - $1"
}

cd "${SCRIPT_DIR}"
. ./sendtoelementsnode.sh
trace() { :; }
trace_rc() { :; }

SPENDER_ELEMENTS_NODE_RPC_URL=http://elements:18884/wallet
SPENDER_ELEMENTS_NODE_RPC_CFG=/tmp/elements.conf
SPENDER_ELEMENTS_NODE_DEFAULT_WALLET=spending01.dat
CURL_ARGS_FILE=${TEST_TMPDIR}/curl-args
CURL_RESPONSE='{"result":"ok","error":null}'

curl() {
  : > "${CURL_ARGS_FILE}"
  for arg in "$@"; do
    printf '%s\n' "${arg}" >> "${CURL_ARGS_FILE}"
  done
  printf '%s\n' "${CURL_RESPONSE}"
}

send_to_elements_spender_node '{"method":"getwalletinfo","params":[]}' 02 >/dev/null || fail "valid spender wallet was rejected"
[ "$(grep -Fxc -- '--url' "${CURL_ARGS_FILE}")" -eq 1 ] || fail "curl did not receive exactly one --url option"
grep -Fx 'http://elements:18884/wallet/spending02.dat' "${CURL_ARGS_FILE}" >/dev/null || fail "wallet URL was not passed as one argument"
pass "spender wallet is mapped to one fixed curl URL"

rm -f "${CURL_ARGS_FILE}"
if send_to_elements_spender_node '{"method":"getwalletinfo","params":[]}' '01 --url http://attacker.invalid' >/dev/null; then
  fail "malicious wallet selector was accepted"
fi
[ ! -e "${CURL_ARGS_FILE}" ] || fail "curl ran for an invalid wallet selector"
pass "invalid wallet selector is rejected before curl"

CURL_RESPONSE='not-json'
if send_to_elements_spender_node '{"method":"getwalletinfo","params":[]}' 01 >/dev/null; then
  fail "malformed JSON-RPC response was accepted"
fi
CURL_RESPONSE='{"result":null,"error":{"code":-1,"message":"failure"}}'
if send_to_elements_spender_node '{"method":"getwalletinfo","params":[]}' 01 >/dev/null; then
  fail "JSON-RPC error response was accepted"
fi
pass "malformed and error JSON-RPC responses fail closed"

. ./elements_blockchainrpc.sh
RPC_DATA_FILE=${TEST_TMPDIR}/rpc-data
send_to_elements_spender_node() {
  printf '%s\n' "${1}" > "${RPC_DATA_FILE}"
  echo '{"result":{"ismine":false},"error":null}'
}
elements_getaddressinfo 'invalid"address' true 01 >/dev/null || fail "getaddressinfo wrapper rejected a valid RPC envelope"
jq -e '.method == "getaddressinfo" and .params == ["invalid\"address"]' "${RPC_DATA_FILE}" >/dev/null || fail "getaddressinfo did not encode the address as JSON data"
pass "getaddressinfo encodes user input without altering JSON-RPC structure"

send_to_elements_watcher_node() { return 7; }
if elements_get_blockchain_info >/dev/null; then
  fail "getblockchaininfo hid an Elements RPC failure"
fi
if elements_get_mempool_info >/dev/null; then
  fail "getmempoolinfo hid an Elements RPC failure"
fi
if elements_get_blockhash 1 >/dev/null; then
  fail "getblockhash hid an Elements RPC failure"
fi
pass "filtered blockchain RPC endpoints preserve node failures"

. ./elements.sh
ELEMENTS_NETWORK=regtest
convert_pub32() { echo tpub-test; }
send_to_elements_watcher_node() {
  echo '{"result":null,"error":{"code":-1,"message":"failure"}}'
  return 7
}
if elements_derive_addresses tpub-test '0/0' >/dev/null; then
  fail "address derivation hid an Elements RPC failure"
fi
pass "address derivation preserves node failures"

. ./elements_walletoperations.sh
GETNEWADDRESS_RPC_FILE=${TEST_TMPDIR}/getnewaddress-rpc
send_to_elements_spender_node() {
  printf '%s\n' "${1}" > "${GETNEWADDRESS_RPC_FILE}"
  echo '{"result":"ert1qexample","error":null}'
  return 0
}
malicious_label='x"} | .method="dumpprivkey" | .params=["ert1qtarget"] | . += {"ignored":"y'
malicious_address_type='bech32"} | .method="dumpprivkey" | .params=["ert1qtarget"] | . += {"ignored":"y'
getnewaddress_response=$(elements_getnewaddress "${malicious_address_type}" "${malicious_label}" 02) || fail "getnewaddress rejected string inputs"
jq -e --arg label "${malicious_label}" --arg address_type "${malicious_address_type}" '
  .method == "getnewaddress"
  and .params.label == $label
  and .params.address_type == $address_type
' "${GETNEWADDRESS_RPC_FILE}" >/dev/null || fail "getnewaddress input altered the JSON-RPC structure"
echo "${getnewaddress_response}" | jq -e --arg label "${malicious_label}" --arg address_type "${malicious_address_type}" '
  .address == "ert1qexample"
  and .label == $label
  and .address_type == $address_type
' >/dev/null || fail "getnewaddress response did not preserve inputs as data"
pass "getnewaddress keeps request fields out of the jq program"

send_to_elements_spender_node() {
  echo '{"result":null,"error":{"code":-1,"message":"failure"}}'
  return 7
}
send_to_xpub_elements_watcher_wallet() {
  echo '{"result":null,"error":{"code":-1,"message":"failure"}}'
  return 7
}
if elements_getwalletinfo >/dev/null; then
  fail "getwalletinfo hid an Elements RPC failure"
fi
if elements_getbalancebyxpub tpub-test >/dev/null; then
  fail "xpub balance lookup hid an Elements RPC failure"
fi
pass "filtered wallet RPC endpoints preserve node failures"

send_to_elements_spender_node() {
  echo '{"result":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","error":null}'
  return 0
}
elements_get_transaction() {
  echo '{"result":{"timereceived":1,"details":[{"amount":-0.1,"fee":-0.0001}],"bip125-replaceable":"no"},"error":null}'
}
elements_get_rawtransaction() {
  echo '{"result":{"hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":100,"vsize":90},"error":null}'
}
elements_getaddressinfo() {
  echo '{"result":{"unconfidential":"ert1qowned"},"error":null}'
}
mosquitto_pub() { return 1; }
sql() {
  case "${1}" in
    *"RETURNING id"*) echo 1 ;;
  esac
}

spend_response=$(elements_spend '{"address":"el1qqdestination","amount":0.1,"eventMessage":"event"}')
spend_rc=$?
[ "${spend_rc}" -eq 0 ] || fail "optional MQTT failure changed successful spend status"
echo "${spend_response}" | jq -e '.status == "accepted"' >/dev/null || fail "successful spend response was not accepted"
pass "optional event failure does not report a broadcast failure"

. ./elements_confirmation.sh
asset_a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
asset_b=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
tx_details='{"details":[{"address":"ert1qowned","category":"send","amount":-1,"asset":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","vout":0},{"address":"ert1qowned","category":"receive","amount":1,"asset":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","vout":0},{"address":"ert1qowned","category":"receive","amount":2,"asset":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","vout":1}]}'

match=$(elements_matching_detail "${tx_details}" ert1qowned "${asset_a}")
echo "${match}" | jq -e --arg asset "${asset_a}" '.amount != 0 and .asset == $asset and .vout == 0' >/dev/null || fail "asset-specific watch matched the wrong asset or vout"
[ -z "$(elements_matching_detail "${tx_details}" ert1qowned cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc)" ] || fail "wrong asset consumed a watch"
echo "$(elements_matching_detail "${tx_details}" ert1qowned "")" | jq -e '.amount != 0 and .vout == 0' >/dev/null || fail "asset-agnostic watch did not select the first output"
outgoing_details='{"details":[{"address":"ert1qxpub","category":"send","amount":-3,"asset":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","vout":2}]}'
echo "$(elements_matching_detail "${outgoing_details}" ert1qxpub "${asset_a}")" | jq -e '.amount == -3 and .vout == 2' >/dev/null || fail "xpub-watched send detail was rejected"
pass "watch matching preserves wallet perspective and exact asset identity"

WALLETNOTIFY_SCRIPT=${SCRIPT_DIR}/../../../cyphernodeconf_docker/templates/elements/walletnotify.sh
grep -F 'spending0[1-4].dat)' "${WALLETNOTIFY_SCRIPT}" >/dev/null || fail "spending-wallet notifications are not routed through their own wallet"
grep -F 'watching01.dat|xpubwatching01.dat)' "${WALLETNOTIFY_SCRIPT}" >/dev/null || fail "watch-only wallets were excluded from Cyphernode notifications"
grep -F 'rpc_wallet=spending01.dat' "${WALLETNOTIFY_SCRIPT}" >/dev/null || fail "watch-only notifications lost the complete spending-wallet view"
pass "wallet notifications preserve spender and watch-only wallet semantics"

elements_validateaddress() {
  echo '{"result":{"isvalid":true},"error":null}'
}
ADDRESS_OWNED=false
elements_getaddressinfo() {
  if ${ADDRESS_OWNED}; then
    echo '{"result":{"ismine":true,"unconfidential":"ert1qowned"},"error":null}'
  else
    echo '{"result":{"ismine":false},"error":null}'
  fi
}
SQL_LOG=${TEST_TMPDIR}/sql-log
sql() {
  printf '%s\n' "${1}" >> "${SQL_LOG}"
  if [ "$#" -gt 1 ]; then
    printf '%s\n' "${2}" >> "${SQL_LOG}"
  fi
  echo 42
}

if elements_watchrequest '{"address":"el1qqexternal"}' >/dev/null; then
  fail "external Elements address was accepted without a blinding key"
fi
[ ! -e "${SQL_LOG}" ] || fail "external Elements watch reached the database"
pass "external Elements watches are rejected before persistence"

ADDRESS_OWNED=true
elements_watchrequest '{"address":"el1qqowned","assetId":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' >/dev/null || fail "owned Elements address was rejected"
grep -F "COALESCE(watching_assetid, '')" "${SQL_LOG}" >/dev/null || fail "asset was omitted from watch conflict identity"
grep -F "watching_assetid='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'" "${SQL_LOG}" >/dev/null || fail "asset was omitted from watch fallback lookup"
pass "owned-address watch persists asset-specific identity"

rm -f "${SQL_LOG}"
valid_txid=dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
if elements_watchtxidrequest "{\"txid\":\"${valid_txid}\"}" >/dev/null; then
  fail "txid watch without a callback was accepted"
fi
[ ! -e "${SQL_LOG}" ] || fail "invalid txid watch reached the database"

elements_watchtxidrequest "{\"txid\":\"${valid_txid}\",\"xconfCallbackURL\":\"https://callback.invalid/x\",\"nbxconf\":2}" >/dev/null || fail "x-conf-only txid watch was rejected"
grep -F "COALESCE(callback1conf, '')" "${SQL_LOG}" >/dev/null || fail "txid watch did not use the fresh-schema conflict identity"
pass "x-conf-only txid watch validates and upserts"

. ./elements_callbacks_txid.sh
CALLBACK_SQL_LOG=${TEST_TMPDIR}/callback-sql-log
sql() {
  printf '%s\n' "${1}" >> "${CALLBACK_SQL_LOG}"
  case "${1}" in
    SELECT*"callback1conf IS NOT NULL"*) echo "1|${valid_txid}|https://callback.invalid/one|1" ;;
    SELECT*"callbackxconf IS NOT NULL"*) echo "2|${valid_txid}|https://callback.invalid/x|2" ;;
  esac
}
elements_build_callback_txid() { return 0; }

cd "${TEST_TMPDIR}"
elements_do_callbacks_txid
grep -F "watching=(callbackxconf IS NOT NULL)" "${CALLBACK_SQL_LOG}" >/dev/null || fail "one-conf-only watch was not closed after callback"
grep -F "(calledback1conf OR callback1conf IS NULL)" "${CALLBACK_SQL_LOG}" >/dev/null || fail "x-conf-only watch was not eligible for callback"
grep -F "calledbackxconf=true, watching=false WHERE id=2" "${CALLBACK_SQL_LOG}" >/dev/null || fail "x-conf-only callback was not completed"
pass "txid callback state handles one-conf-only and x-conf-only watches"

echo "All Elements regression tests passed."
