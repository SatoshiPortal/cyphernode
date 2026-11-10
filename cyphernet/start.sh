#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export CYPHERNET_DATA_DIR=${CYPHERNET_DATA_DIR:-"$script_dir/data"}
umask 077
mkdir -p "$CYPHERNET_DATA_DIR/bitcoin" "$CYPHERNET_DATA_DIR/core-lightning"
CYPHERNET_DATA_DIR=$(cd "$CYPHERNET_DATA_DIR" && pwd)
chmod 700 "$CYPHERNET_DATA_DIR" "$CYPHERNET_DATA_DIR/bitcoin" "$CYPHERNET_DATA_DIR/core-lightning"
export CYPHERNET_DATA_DIR
export CYPHERNET_UID=$(id -u)
export CYPHERNET_GID=$(id -g)

if [[ ! -f "$CYPHERNET_DATA_DIR/rpc-password" ]]; then
  od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > "$CYPHERNET_DATA_DIR/rpc-password"
fi
rpc_password=$(cat "$CYPHERNET_DATA_DIR/rpc-password")
if [[ ! "$rpc_password" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Invalid Cyphernet RPC password file" >&2
  exit 1
fi
if [[ -n "${CYPHERNET_PUBLIC_HOST:-}" && ! "$CYPHERNET_PUBLIC_HOST" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "CYPHERNET_PUBLIC_HOST must be an IPv4 address or DNS name" >&2
  exit 1
fi

if [[ ! -f "$CYPHERNET_DATA_DIR/bitcoin/bitcoin.conf" ]]; then
  cat > "$CYPHERNET_DATA_DIR/bitcoin/bitcoin.conf" <<EOF
signet=1
server=1
txindex=1
dbcache=300
rpcuser=cyphernet
rpcpassword=$rpc_password

[signet]
signetchallenge=0014dc9786c6b1c3ad2bcc45014b40384fba3419de17
signetblocktime=30
dnsseed=0
listenonion=0
addnode=170.75.166.64:38333
port=38333
rpcport=38332
rpcbind=0.0.0.0
rpcallowip=0.0.0.0/0
EOF
fi

if [[ ! -f "$CYPHERNET_DATA_DIR/bitcoin-client.conf" ]]; then
  cat > "$CYPHERNET_DATA_DIR/bitcoin-client.conf" <<EOF
signet=1
rpcuser=cyphernet
rpcpassword=$rpc_password

[signet]
rpcconnect=bitcoin
rpcport=38332
EOF
fi

if [[ ! -f "$CYPHERNET_DATA_DIR/core-lightning/config" ]]; then
  cat > "$CYPHERNET_DATA_DIR/core-lightning/config" <<EOF
network=signet
bitcoin-datadir=/.bitcoin
addr=0.0.0.0:9735
alias=Cyphernet Core Lightning
disable-dns
EOF
  if [[ -n "${CYPHERNET_PUBLIC_HOST:-}" ]]; then
    printf 'announce-addr=%s:9735\n' "$CYPHERNET_PUBLIC_HOST" >> "$CYPHERNET_DATA_DIR/core-lightning/config"
  fi
fi

if [[ ${CYPHERNET_SKIP_BUILD:-0} != 1 ]]; then
  docker compose -p cyphernet -f "$script_dir/compose.yaml" build bitcoin
fi
docker compose -p cyphernet -f "$script_dir/compose.yaml" up -d
docker compose -p cyphernet -f "$script_dir/compose.yaml" ps
