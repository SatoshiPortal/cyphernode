FROM rust:1.86.0-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    procps \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/paymentalist

COPY Cargo.toml Cargo.lock ./
RUN cargo fetch --locked

COPY ./src ./src
COPY ./config ./config
COPY ./test ./test

RUN cargo build --release --locked

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /usr/src/paymentalist/target/release/paymentalist /usr/local/bin/paymentalist
COPY --from=builder /usr/src/paymentalist/config /app/config

RUN chmod +x /usr/local/bin/paymentalist

ENV RUST_LOG=info,paymentalist=info,tower_http=info

CMD ["/usr/local/bin/paymentalist"]
