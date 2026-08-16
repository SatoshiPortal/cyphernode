#!/bin/sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)
DB_PATH=$(mktemp -d "${TMPDIR:-/tmp}/cyphernode-prepared-test.XXXXXX")
export DB_PATH
trap 'rm -rf -- "${DB_PATH}"' EXIT HUP INT TERM

cd "${APP_DIR}/script"
. ./prepared_transactions.sh

send_to_spender_wallet_name() {
  case $(printf '%s' "$2" | jq -r '.method') in
    createrawtransaction) printf '%s\n' '{"result":"00","error":null,"id":"1"}' ;;
    fundrawtransaction) printf '%s\n' '{"result":{"hex":"02","fee":0.00001},"error":null,"id":"1"}' ;;
    signrawtransactionwithwallet) printf '%s\n' '{"result":{"hex":"04","complete":true},"error":null,"id":"1"}' ;;
    decoderawtransaction) printf '%s\n' '{"result":{"txid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","vin":[{"txid":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","vout":0}],"vout":[{"value":0.001,"scriptPubKey":{"address":"bc1qdestination","type":"witness_v0_keyhash"}},{"value":0.00001,"scriptPubKey":{"type":"fee"}}]},"error":null,"id":"1"}' ;;
    lockunspent) printf '%s\n' '{"result":true,"error":null,"id":"1"}' ;;
    *) return 1 ;;
  esac
}

request='{"operationId":"00000000-0000-4000-8000-000000000001","leg":"funding","wallet":"treasury-btc.dat","address":"bc1qdestination","amountSatoshis":"100000","maximumFeeSatoshis":"2000"}'
response=$(prepared_transfer bitcoin "${request}")
printf '%s' "${response}" | jq -e '
  .error == null
  and .result.expectedTxid == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  and .result.outputAmountSatoshis == "100000"
  and .result.feeSatoshis == "1000"
  and .result.outputAddress == "bc1qdestination"
' >/dev/null
# The durable operation/leg cache must return identical bytes without touching
# the wallet again after a lost HTTP response.
send_to_spender_wallet_name() {
  case $(printf '%s' "$2" | jq -r '.method') in
    decoderawtransaction) printf '%s\n' '{"result":{"txid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","vin":[{"txid":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","vout":0}],"vout":[]},"error":null,"id":"1"}' ;;
    lockunspent) printf '%s\n' '{"result":true,"error":null,"id":"1"}' ;;
    *) return 1 ;;
  esac
}
response=$(prepared_transfer bitcoin "${request}")
printf '%s' "${response}" | jq -e '.result.signedHex == "04"' >/dev/null

contradictory=$(printf '%s' "${request}" | jq -c '.amountSatoshis="99999"')
if prepared_transfer bitcoin "${contradictory}" >/dev/null 2>&1; then
  echo "contradictory idempotency request was accepted" >&2
  exit 1
fi

send_to_elements_spender_wallet_name() {
  case $(printf '%s' "$2" | jq -r '.method') in
    createrawtransaction)
      # elementsd type-checks the outputs parameter as an ARRAY (VARR); the
      # object form Bitcoin accepts fails with "Expected type array, got
      # object". Enforce that here so the mock cannot silently disagree with
      # the real node.
      if ! printf '%s' "$2" | jq -e '.params[1] | type == "array"' >/dev/null; then
        printf '%s\n' '{"result":null,"error":{"code":-3,"message":"Expected type array, got object"},"id":"1"}'
      else
        printf '%s\n' '{"result":"10","error":null,"id":"1"}'
      fi
      ;;
    validateaddress) printf '%s\n' '{"result":{"isvalid":true,"address":"el1qdestination","confidential_key":"03aa","unconfidential":"ert1qdestination"},"error":null,"id":"1"}' ;;
    fundrawtransaction) printf '%s\n' '{"result":{"hex":"12","fee":0.00001},"error":null,"id":"1"}' ;;
    blindrawtransaction) printf '%s\n' '{"result":"13","error":null,"id":"1"}' ;;
    signrawtransactionwithwallet) printf '%s\n' '{"result":{"hex":"14","complete":true},"error":null,"id":"1"}' ;;
    decoderawtransaction)
      # Elements decodes with the UNCONFIDENTIAL address form; the blinding
      # key is surfaced separately (commitmentnonce), never in .address.
      if [ "$(printf '%s' "$2" | jq -r '.params[0]')" = 12 ]; then
        printf '%s\n' '{"result":{"txid":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","vin":[{"txid":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","vout":1}],"vout":[{"value":0.001,"scriptPubKey":{"address":"ert1qdestination"}},{"value":0.0005,"scriptPubKey":{"address":"ert1qchange"}}]},"error":null,"id":"1"}'
      else
        # A confidential signed output has commitments, but no public value.
        printf '%s\n' '{"result":{"txid":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","vin":[{"txid":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","vout":1}],"vout":[{"valuecommitment":"08aa","scriptPubKey":{"address":"ert1qdestination"}},{"valuecommitment":"08bb","scriptPubKey":{"address":"ert1qchange"}}]},"error":null,"id":"1"}'
      fi
      ;;
    lockunspent) printf '%s\n' '{"result":true,"error":null,"id":"1"}' ;;
    *) return 1 ;;
  esac
}

elements_request='{"operationId":"00000000-0000-4000-8000-000000000003","leg":"direct","wallet":"treasury-elements.dat","address":"el1qdestination","amountSatoshis":"100000","maximumFeeSatoshis":"2000"}'
response=$(prepared_transfer elements "${elements_request}")
printf '%s' "${response}" | jq -e '
  .error == null
  and .result.expectedTxid == "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
  and .result.outputAmountSatoshis == "100000"
  and .result.outputAddress == "el1qdestination"
' >/dev/null

# A rejected prepare must release the inputs fundrawtransaction locked: the
# fee-cap failure below must be followed by an unlock (lockunspent true).
UNLOCK_LOG="${DB_PATH}/unlock.log"
: > "${UNLOCK_LOG}"
send_to_spender_wallet_name() {
  case $(printf '%s' "$2" | jq -r '.method') in
    createrawtransaction) printf '%s\n' '{"result":"00","error":null,"id":"1"}' ;;
    fundrawtransaction) printf '%s\n' '{"result":{"hex":"02","fee":0.00099},"error":null,"id":"1"}' ;;
    decoderawtransaction) printf '%s\n' '{"result":{"txid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","vin":[{"txid":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","vout":0}],"vout":[]},"error":null,"id":"1"}' ;;
    lockunspent)
      printf '%s\n' "$2" | jq -r '.params[0]' >> "${UNLOCK_LOG}"
      printf '%s\n' '{"result":true,"error":null,"id":"1"}'
      ;;
    *) return 1 ;;
  esac
}
overfee='{"operationId":"00000000-0000-4000-8000-000000000004","leg":"funding","wallet":"treasury-btc.dat","address":"bc1qdestination","amountSatoshis":"100000","maximumFeeSatoshis":"2000"}'
if prepared_transfer bitcoin "${overfee}" 2>/dev/null | jq -e '.error == null' >/dev/null 2>&1; then
  echo "over-budget prepare was accepted" >&2
  exit 1
fi
grep -qx true "${UNLOCK_LOG}" || {
  echo "rejected prepare did not release its locked inputs" >&2
  exit 1
}

echo "Prepared transaction tests passed"
