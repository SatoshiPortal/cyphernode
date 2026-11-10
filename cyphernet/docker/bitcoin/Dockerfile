FROM ubuntu:24.04 AS build

RUN sed -i -e 's#http://archive.ubuntu.com/ubuntu#http://mirrors.edge.kernel.org/ubuntu#g' \
    -e 's#http://security.ubuntu.com/ubuntu#http://mirrors.edge.kernel.org/ubuntu#g' \
    /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates cmake git libboost-dev libsqlite3-dev ninja-build python3 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v32.1 https://github.com/bitcoin/bitcoin.git /src \
    && test "$(git -C /src rev-parse HEAD)" = f0de87f040621468b956f01f526a43a010310501
COPY cyphernet-core.patch /tmp/cyphernet-core.patch
RUN cd /src && git apply /tmp/cyphernet-core.patch \
    && cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_GUI=OFF -DBUILD_TESTS=OFF \
      -DBUILD_TX=OFF -DBUILD_UTIL=OFF -DENABLE_IPC=OFF -DENABLE_WALLET=ON \
    && cmake --build build --target bitcoind bitcoin-cli -j 2

FROM ubuntu:24.04
RUN sed -i -e 's#http://archive.ubuntu.com/ubuntu#http://mirrors.edge.kernel.org/ubuntu#g' \
    -e 's#http://security.ubuntu.com/ubuntu#http://mirrors.edge.kernel.org/ubuntu#g' \
    /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/build/bin/bitcoind /usr/local/bin/bitcoind
COPY --from=build /src/build/bin/bitcoin-cli /usr/local/bin/bitcoin-cli
CMD ["bitcoind", "-datadir=/bitcoin", "-printtoconsole"]
