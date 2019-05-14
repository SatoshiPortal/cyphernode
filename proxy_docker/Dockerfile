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

RUN chmod +x startproxy.sh requesthandler.sh lightning-cli sqlmigrate*.sh waitanyinvoice.sh \
 && chmod o+w . \
 && mkdir db

VOLUME ["${HOME}/db", "/.lightning"]

ENTRYPOINT ["su-exec"]
