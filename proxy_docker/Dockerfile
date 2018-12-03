FROM alpine:3.8

# Taking care of glibc shit (glibc not natively supported by Alpine but lightning-cli uses it)

ENV GLIBC_VERSION 2.27-r0
ENV GLIBC_SHA256 938bceae3b83c53e7fa9cc4135ce45e04aae99256c5e74cf186c794b97473bc7
ENV GLIBCBIN_SHA256 3a87874e57b9d92e223f3e90356aaea994af67fb76b71bb72abfb809e948d0d6
# Download and install glibc (https://github.com/jeanblanchard/docker-alpine-glibc/blob/master/Dockerfile)
RUN wget -O /etc/apk/keys/sgerrand.rsa.pub https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/sgerrand.rsa.pub \
 && wget -O glibc.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk" \
 && echo "$GLIBC_SHA256  glibc.apk" | sha256sum -c - \
 && wget -O glibc-bin.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk" \
 && echo "$GLIBCBIN_SHA256  glibc-bin.apk" | sha256sum -c - \
 && apk add --update --no-cache glibc-bin.apk glibc.apk \
 && /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib \
 && echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf \
 && rm -rf glibc.apk glibc-bin.apk

ENV HOME /proxy

RUN apk add --update --no-cache \
    sqlite \
    jq \
    curl \
    su-exec

COPY app/script/callbacks_job.sh ${HOME}/callbacks_job.sh
COPY app/script/blockchainrpc.sh ${HOME}/blockchainrpc.sh
COPY app/script/call_lightningd.sh ${HOME}/call_lightningd.sh
COPY app/script/bitcoin.sh ${HOME}/bitcoin.sh
COPY app/script/ots.sh ${HOME}/ots.sh
COPY app/script/requesthandler.sh ${HOME}/requesthandler.sh
COPY app/script/watchrequest.sh ${HOME}/watchrequest.sh
COPY app/script/walletoperations.sh ${HOME}/walletoperations.sh
COPY app/script/confirmation.sh ${HOME}/confirmation.sh
COPY app/script/startproxy.sh ${HOME}/startproxy.sh
COPY app/script/trace.sh ${HOME}/trace.sh
COPY app/script/sendtobitcoinnode.sh ${HOME}/sendtobitcoinnode.sh
COPY app/script/responsetoclient.sh ${HOME}/responsetoclient.sh
COPY app/script/importaddress.sh ${HOME}/importaddress.sh
COPY app/script/sql.sh ${HOME}/sql.sh
COPY app/data/watching.sql ${HOME}/watching.sql
COPY app/script/computefees.sh ${HOME}/computefees.sh
COPY app/script/unwatchrequest.sh ${HOME}/unwatchrequest.sh
COPY app/script/getactivewatches.sh ${HOME}/getactivewatches.sh
COPY app/script/manage_missed_conf.sh ${HOME}/manage_missed_conf.sh
COPY app/script/tests.sh ${HOME}/tests.sh
COPY app/script/tests-cb.sh ${HOME}/tests-cb.sh
COPY --from=cyphernode/clightning:v0.6.2 /usr/bin/lightning-cli ${HOME}/lightning-cli

WORKDIR ${HOME}

RUN chmod +x startproxy.sh requesthandler.sh lightning-cli \
 && chmod o+w . \
 && mkdir db

VOLUME ["${HOME}/db", "${HOME}/.lightning"]

ENTRYPOINT ["su-exec"]
