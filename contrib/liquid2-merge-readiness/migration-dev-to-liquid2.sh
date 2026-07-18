#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null && pwd)"
PROXY_IMAGE="${PROXY_IMAGE:-cyphernode/proxy:codex-liquid2-ready}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:14.0-bullseye}"
KEEP_TEST_ROOT="${KEEP_TEST_ROOT:-0}"

cd "$ROOT_DIR"

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

need docker
need git

if ! docker image inspect "$PROXY_IMAGE" >/dev/null 2>&1; then
  docker build proxy_docker -t "$PROXY_IMAGE"
fi
pass "candidate proxy image available: $PROXY_IMAGE"

test_root="$(mktemp -d)"
network_name="liquid2-migration-$RANDOM-$$"
postgres_name="liquid2-migration-postgres-$RANDOM-$$"

cleanup() {
  docker rm -f "$postgres_name" >/dev/null 2>&1 || true
  docker network rm "$network_name" >/dev/null 2>&1 || true
  if [ "$KEEP_TEST_ROOT" != "1" ]; then
    rm -rf "$test_root"
  else
    printf 'kept test root: %s\n' "$test_root" >&2
  fi
}
trap cleanup EXIT

mkdir -p "$test_root/dev" "$test_root/db"
git show origin/dev:proxy_docker/app/data/cyphernode.sql > "$test_root/dev/cyphernode.sql"
git show origin/dev:proxy_docker/app/data/cyphernode.postgresql > "$test_root/dev/cyphernode.postgresql"

docker network create "$network_name" >/dev/null
docker run -d --rm \
  --name "$postgres_name" \
  --network "$network_name" \
  --network-alias postgres \
  -e POSTGRES_USER=cyphernode \
  -e POSTGRES_DB=cyphernode \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  "$POSTGRES_IMAGE" >/dev/null

docker run --rm --network "$network_name" "$PROXY_IMAGE" sh -c '
  for i in $(seq 1 60); do
    pg_isready -h postgres -U cyphernode >/dev/null 2>&1 && exit 0
    sleep 1
  done
  exit 1
'
pass "isolated PostgreSQL is ready"

docker run --rm \
  --network "$network_name" \
  -v "$test_root/dev:/dev-schema:ro" \
  -v "$test_root/db:/proxy/db" \
  "$PROXY_IMAGE" sh -c '
    set -e
    sqlite3 /proxy/db/cyphernode.sqlite < /dev-schema/cyphernode.sql
    psql -v ON_ERROR_STOP=1 -h postgres -U cyphernode -f /dev-schema/cyphernode.postgresql >/dev/null
    psql -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "
      INSERT INTO watching (address, label, watching, callback0conf, callback1conf, imported)
      VALUES ('\''bcrt1qliquid2migrationwatch000000000000000000000'\'', '\''migration-bitcoin-watch'\'', true, '\''http://127.0.0.1:1/0conf'\'', '\''http://127.0.0.1:1/1conf'\'', true);
      INSERT INTO watching_by_txid (txid, watching, callback1conf, callbackxconf, nbxconf)
      VALUES ('\''4444444444444444444444444444444444444444444444444444444444444444'\'', true, '\''http://127.0.0.1:1/1conf'\'', '\''http://127.0.0.1:1/xconf'\'', 6);
      INSERT INTO watching_by_pub32 (pub32, label, derivation_path, callback0conf, callback1conf, last_imported_n, watching)
      VALUES ('\''tpubD6NzVbkrYhZ4YmigrationOnlyNotUsedByNode111111111111111111111111111'\'', '\''migration-xpub-watch'\'', '\''0/n'\'', '\''http://127.0.0.1:1/0conf'\'', '\''http://127.0.0.1:1/1conf'\'', 0, true);
    " >/dev/null
  '
pass "origin/dev SQLite and PostgreSQL schemas created with sample Bitcoin data"

run_migrations() {
  docker run --rm \
    --network "$network_name" \
    -v "$test_root/db:/proxy/db" \
    -e DB_FILE=/proxy/db/cyphernode.sqlite \
    -e DB_PATH=/proxy/db \
    "$PROXY_IMAGE" sh -c '
      set -e
      for script in sqlmigrate*.sh; do
        sh "$script" >/tmp/migration.log
      done
    '
}

run_migrations
pass "candidate migrations completed from origin/dev schema"

run_migrations
pass "candidate migrations are idempotent on second run"

docker run --rm --network "$network_name" "$PROXY_IMAGE" sh -c '
  set -e
  psql -qAtX -v ON_ERROR_STOP=1 -h postgres -U cyphernode -c "
    SELECT COUNT(*) = 1 FROM watching WHERE label = '\''migration-bitcoin-watch'\'';
    SELECT COUNT(*) = 1 FROM watching_by_txid WHERE txid = '\''4444444444444444444444444444444444444444444444444444444444444444'\'';
    SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '\''elements_watching'\'');
    SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '\''elements_watching_by_txid'\'');
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = '\''elements_watching'\'' AND column_name = '\''watching_assetid'\'');
    SELECT indexdef LIKE '\''%COALESCE(watching_assetid%'\'' FROM pg_indexes WHERE indexname = '\''idx_elements_watching_01'\'';
  " | grep -qxF f && exit 1 || exit 0
'
pass "Bitcoin data survived and Liquid tables/indexes exist after migration"
