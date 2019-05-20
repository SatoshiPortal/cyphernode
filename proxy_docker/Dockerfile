FROM cyphernode/alpine-glibc-base:3.8

ENV HOME /proxy

RUN apk add --update --no-cache \
    sqlite \
    jq \
    curl \
    su-exec

WORKDIR ${HOME}

COPY app/data/* ./
COPY app/script/* ./
COPY --from=cyphernode/clightning:v0.7.0-test /usr/local/bin/lightning-cli ./
COPY --from=eclipse-mosquitto:1.6 /usr/bin/mosquitto_rr /usr/bin/mosquitto_sub /usr/bin/mosquitto_pub /usr/bin/
COPY --from=eclipse-mosquitto:1.6 /usr/lib/libmosquitto* /usr/lib/

RUN chmod +x startproxy.sh requesthandler.sh lightning-cli sqlmigrate*.sh waitanyinvoice.sh tests* \
 && chmod o+w . \
 && mkdir db

VOLUME ["${HOME}/db", "/.lightning"]

ENTRYPOINT ["su-exec"]
