# Bitcoin Core for a custom signet with its own block time.
#
# Bitcoin Core fixes signet's target block spacing at 600 seconds, and that
# spacing drives difficulty adjustment, so a node of a signet mined at another
# pace rejects its blocks after the first retarget. signetblocktime.patch adds
# -signetblocktime, accepted only together with -signetchallenge. Without it
# the node behaves as stock Bitcoin Core.
#
# The runtime image carries what Cyphernode's bitcoin scripts use
# (mosquitto_pub, curl, jq) and ZMQ, like cyphernode/bitcoin.

FROM ubuntu:24.04 AS build

ARG BITCOIN_TAG=v32.1
ARG BITCOIN_COMMIT=f0de87f040621468b956f01f526a43a010310501

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates cmake git libboost-dev libsqlite3-dev libzmq3-dev \
    ninja-build pkg-config python3 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${BITCOIN_TAG} https://github.com/bitcoin/bitcoin.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "${BITCOIN_COMMIT}"
COPY signetblocktime.patch /tmp/signetblocktime.patch
RUN cd /src && git apply /tmp/signetblocktime.patch \
    && cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_GUI=OFF -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF \
      -DBUILD_TX=OFF -DBUILD_UTIL=OFF -DENABLE_IPC=OFF -DENABLE_WALLET=ON -DWITH_ZMQ=ON \
    && cmake --build build --target bitcoind bitcoin-cli -j "$(nproc)"

FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq libsqlite3-0 libzmq5 mosquitto-clients \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/build/bin/bitcoind /usr/bin/bitcoind
COPY --from=build /src/build/bin/bitcoin-cli /usr/bin/bitcoin-cli

ENV HOME=/
WORKDIR /usr/bin
CMD ["bash"]
