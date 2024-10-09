FROM debian:bullseye-slim

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
 && apt -y remove gpg \
 && apt -y autoremove

 COPY app/data/* ./
 COPY app/script/* ./
 COPY app/tests/* ./tests/
 COPY --from=cyphernode/clightning:v22.11.1-debian /usr/local/bin/lightning-cli ./

 RUN chmod +x startproxy.sh requesthandler.sh lightning-cli sqlmigrate*.sh waitanyinvoice.sh \
              bitcoin_node_walletnotify.sh bitcoin_node_newtip.sh confirmation.sh processnewtip.sh tests/* \
  && chmod o+w . \
  && mkdir db

VOLUME ["${HOME}/db", "/.lightning"]
