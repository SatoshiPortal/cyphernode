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
 && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null \
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" \
    > /etc/apt/sources.list.d/postgresql.list \
 && apt update && apt install -y \
    postgresql-14 \
 && apt -y remove gpg \
 && apt -y autoremove

 COPY app/data/* ./
 COPY app/script/* ./
 COPY app/tests/* ./tests/
 COPY --from=cyphernode/clightning:v0.11.2-debian /usr/local/bin/lightning-cli ./

 RUN chmod +x startproxy.sh requesthandler.sh lightning-cli sqlmigrate*.sh waitanyinvoice.sh bitcoin_node_walletnotify.sh bitcoin_node_newtip.sh tests/* \
  && chmod o+w . \
  && mkdir db

VOLUME ["${HOME}/db", "/.lightning"]
