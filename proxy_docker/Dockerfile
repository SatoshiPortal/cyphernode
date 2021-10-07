FROM cyphernode/alpine-glibc-base:v3.12.4_2.31-0

ENV HOME /proxy

RUN apk add --update --no-cache \
    sqlite \
    jq \
    curl \
    su-exec

WORKDIR ${HOME}

COPY app/data/* ./
COPY app/script/* ./
COPY app/tests/* ./tests/
COPY --from=cyphernode/clightning:v0.10.1 /usr/local/bin/lightning-cli ./
COPY --from=eclipse-mosquitto:1.6 /usr/bin/mosquitto_rr /usr/bin/mosquitto_sub /usr/bin/mosquitto_pub /usr/bin/
COPY --from=eclipse-mosquitto:1.6 /usr/lib/libmosquitto* /usr/lib/
COPY --from=eclipse-mosquitto:1.6 /usr/lib/libcrypto* /usr/lib/
COPY --from=eclipse-mosquitto:1.6 /usr/lib/libssl* /usr/lib/

RUN chmod +x startproxy.sh requesthandler.sh lightning-cli sqlmigrate*.sh waitanyinvoice.sh tests/* \
 && chmod o+w . \
 && mkdir db

VOLUME ["${HOME}/db", "/.lightning"]

ENTRYPOINT ["su-exec"]
