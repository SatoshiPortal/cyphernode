FROM alpine

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
COPY app/bin/lightning-cli_x86 ${HOME}/lightning-cli

WORKDIR ${HOME}

RUN chmod +x startproxy.sh requesthandler.sh lightning-cli \
 && chmod o+w . \
 && mkdir db

VOLUME ["${HOME}/db", "${HOME}/.lightning"]

ENTRYPOINT ["su-exec"]

