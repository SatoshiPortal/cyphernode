FROM debian:bookworm-slim

ENV HOME /proxy
WORKDIR ${HOME}

RUN apt update && apt -y install \
    sqlite3 \
    jq \
    curl \
    base58 \
    xxd \
    mosquitto-clients \
    gpg \
    ncat \
    procps \
    postgresql \
    libsodium23 \
 && apt -y remove gpg \
 && apt -y autoremove

 COPY app/data/* ./
 COPY app/script/* ./
 COPY app/tests/* ./tests/
 COPY --from=cyphernode/clightning:v26.06.9 /usr/local/bin/lightning-cli ./

 RUN chmod +x *.sh tests/* \
  && chmod o+w . \
  && mkdir db

VOLUME ["${HOME}/db", "/.lightning"]
