#!/bin/sh
#
# Starts barkd and creates its wallet on first boot.
#
# Environment (set by Cyphernode's barkd.env):
#   ARK_SERVER_URL      Ark server (captaind) URL, required
#   ARK_NETWORK         mainnet | signet | regtest
#   BITCOIND_RPC_URL    http://bitcoin:8332
#   BITCOIND_RPC_USER   RPC user
#   BITCOIND_RPC_PASS   RPC password
#   BARKD_DATADIR       wallet datadir, default /barkd/data
#   BARKD_TOKEN_DIR     where the bearer token is copied for the proxy, default /barkd/token
#   BARKD_BIND_PORT     default 3000
#   BARKD_WAIT_FOR_BITCOIN  wait for Cyphernode's bitcoin container, default true

set -eu
umask 077

DATADIR="${BARKD_DATADIR:-/barkd/data}"
TOKEN_DIR="${BARKD_TOKEN_DIR:-/barkd/token}"
PORT="${BARKD_BIND_PORT:-3000}"
API="http://127.0.0.1:${PORT}/api/v1"
MONITOR=/container_monitor

export BARKD_DATADIR="${DATADIR}"

log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] [barkd] $1"
}

[ -d "${MONITOR}" ] && rm -f "${MONITOR}/barkd_ready"

if [ -z "${ARK_SERVER_URL:-}" ]; then
  log "ARK_SERVER_URL is not set, refusing to start"
  exit 1
fi

mkdir -p "${DATADIR}" "${TOKEN_DIR}"

# One bearer token per datadir. The proxy reads the copy in TOKEN_DIR, so the
# wallet files themselves are never mounted anywhere else.
if [ ! -f "${DATADIR}/auth_token" ]; then
  log "generating auth token"
  barkd secret refresh > /dev/null
fi
cp "${DATADIR}/auth_token" "${TOKEN_DIR}/auth_token.tmp"
chmod 0600 "${TOKEN_DIR}/auth_token.tmp"
mv "${TOKEN_DIR}/auth_token.tmp" "${TOKEN_DIR}/auth_token"
TOKEN=$(cat "${DATADIR}/auth_token")

if [ "${BARKD_WAIT_FOR_BITCOIN:-true}" = "true" ]; then
  while [ ! -f "${MONITOR}/bitcoin_ready" ]; do log "bitcoin not ready"; sleep 10; done
  log "bitcoin ready"
fi

barkd --host 0.0.0.0 --port "${PORT}" &
BARKD_PID=$!

trap 'kill -TERM ${BARKD_PID} 2>/dev/null; wait ${BARKD_PID}' TERM INT

api() {
  # $1 method, $2 path, $3 body (optional)
  if [ -n "${3:-}" ]; then
    curl -s -f -X "$1" -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
      --data "$3" "${API}$2"
  else
    curl -s -f -X "$1" -H "Authorization: Bearer ${TOKEN}" "${API}$2"
  fi
}

until curl -s -f "http://127.0.0.1:${PORT}/ping" > /dev/null; do
  kill -0 ${BARKD_PID} 2>/dev/null || { log "barkd exited during startup"; exit 1; }
  sleep 2
done
log "barkd is up"

# A wallet created while bitcoind is still syncing starts at that old height
# and then fetches every later block before its on-chain calls answer.
wait_for_sync() {
  local info
  while :; do
    info=$(curl -s -u "${BITCOIND_RPC_USER}:${BITCOIND_RPC_PASS}" -H "Content-Type: application/json" \
      --data '{"jsonrpc":"1.0","id":"barkd","method":"getblockchaininfo","params":[]}' "${BITCOIND_RPC_URL}" \
      | jq -r '.result | select(. != null) | "\(.initialblockdownload) \(.blocks)/\(.headers)"')
    case "${info}" in
      false*) return 0 ;;
      "") log "bitcoind not answering, waiting" ;;
      *) log "bitcoind syncing (${info#* }), waiting before creating the wallet" ;;
    esac
    sleep 60
  done
}

fingerprint=$(api GET /wallet | jq -r '.fingerprint // empty')
if [ -z "${fingerprint}" ]; then
  wait_for_sync
  log "no wallet found, creating one on ${ARK_NETWORK:-mainnet} against ${ARK_SERVER_URL}"
  request=$(jq -cn \
    --arg ark "${ARK_SERVER_URL}" \
    --arg network "${ARK_NETWORK:-mainnet}" \
    --arg bitcoind "${BITCOIND_RPC_URL}" \
    --arg user "${BITCOIND_RPC_USER}" \
    --arg pass "${BITCOIND_RPC_PASS}" \
    '{ark_server: $ark, network: $network,
      chain_source: {bitcoind: {bitcoind: $bitcoind, bitcoind_auth: {"user-pass": {user: $user, pass: $pass}}}}}')
  if ! api POST /wallet/create "${request}" > /dev/null; then
    log "wallet creation failed"
    kill -TERM ${BARKD_PID} 2>/dev/null
    wait ${BARKD_PID} || true
    exit 1
  fi
  fingerprint=$(api GET /wallet | jq -r '.fingerprint // empty')
  log "wallet created, fingerprint ${fingerprint}"
  log "back up ${DATADIR} now; it holds the wallet seed"
else
  log "wallet ${fingerprint} loaded"
fi

payout=$(api GET /wallet/fallback | jq -r '.payout_address // empty' || true)
[ -n "${payout}" ] && log "fallback payout address: ${payout}"

wait ${BARKD_PID}
