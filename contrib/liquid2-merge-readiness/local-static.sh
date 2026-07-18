#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null && pwd)"
PROXY_IMAGE="${PROXY_IMAGE:-cyphernode/proxy:liquid2-ready}"
PAYMENTALIST_IMAGE="${PAYMENTALIST_IMAGE:-cyphernode/paymentalist:liquid2-ready}"

cd "$ROOT_DIR"

pass() {
  printf 'ok - %s\n' "$1"
}

run() {
  printf 'running - %s\n' "$*"
  "$@"
}

git merge-base --is-ancestor origin/dev HEAD
pass "origin/dev is an ancestor of HEAD"

git diff --check origin/dev..HEAD
pass "diff check passed"

./proxy_docker/app/tests/test-elements-regressions.sh
pass "Elements shell regression tests passed"

find proxy_docker/app/script proxy_docker/app/tests api_auth_docker -type f -name '*.sh' -print0 \
  | xargs -0 -n 50 sh -n
pass "shell syntax checks passed"

(
  cd paymentalist_docker
  cargo fmt -- --check
  cargo clippy --locked --offline --all-targets -- -D warnings
  cargo test --locked --offline
)
pass "Paymentalist Rust checks passed"

run docker build proxy_docker -t "$PROXY_IMAGE"
pass "proxy image built: $PROXY_IMAGE"

run docker build paymentalist_docker -t "$PAYMENTALIST_IMAGE"
pass "Paymentalist image built: $PAYMENTALIST_IMAGE"

if docker run --rm "$PAYMENTALIST_IMAGE" sh -c 'test ! -e /app/test/bin/create_reverse_swap && test ! -e /paymentalist/test/bin/create_reverse_swap' >/dev/null 2>&1; then
  pass "Paymentalist runtime image does not ship create_reverse_swap helper"
else
  printf 'not ok - Paymentalist runtime image contains create_reverse_swap helper\n' >&2
  exit 1
fi
