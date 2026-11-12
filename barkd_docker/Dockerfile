# barkd: the bark wallet daemon, built from the scuttle fork at a pinned commit.
#
# The wallet lives in /barkd/data. The bearer token the proxy uses is copied
# to /barkd/token/auth_token so the proxy only needs that subdirectory.

FROM rust:1-bookworm AS builder

ARG SCUTTLE_REPO=https://github.com/BullishNode/scuttle.git
ARG SCUTTLE_COMMIT=44032626581caac1a32ff18c537108747476cb2b

RUN apt-get update \
 && apt-get install -y --no-install-recommends git clang pkg-config libssl-dev protobuf-compiler \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone ${SCUTTLE_REPO} . && git checkout --detach ${SCUTTLE_COMMIT}

# No web UI and no swagger UI: the proxy is the only client.
RUN cargo build --release --locked -p bark-cli --bin barkd \
      --no-default-features --features tls-webpki-roots,sqlite-bundled

FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl jq sqlite3 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/target/release/barkd /usr/local/bin/barkd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/barkd"]
EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
