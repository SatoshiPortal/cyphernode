FROM alpine

ARG USER_ID
ARG GROUP_ID
ENV USERNAME proxyuser
ENV HOME /${USERNAME}
ENV USER_ID ${USER_ID:-1000}
ENV GROUP_ID ${GROUP_ID:-1000}

RUN addgroup -g ${GROUP_ID} ${USERNAME} \
    && adduser -u ${USER_ID} -G ${USERNAME} -D -s /bin/sh -h ${HOME} ${USERNAME}

RUN apk add --update --no-cache \
    sqlite \
    jq \
    curl

COPY --chown=proxyuser app/script/callbacks_job.sh ${HOME}/callbacks_job.sh
COPY --chown=proxyuser app/script/blockchainrpc.sh ${HOME}/blockchainrpc.sh
COPY --chown=proxyuser app/script/call_lightningd.sh ${HOME}/call_lightningd.sh
COPY --chown=proxyuser app/script/bitcoin.sh ${HOME}/bitcoin.sh
COPY --chown=proxyuser app/script/requesthandler.sh ${HOME}/requesthandler.sh
COPY --chown=proxyuser app/script/watchrequest.sh ${HOME}/watchrequest.sh
COPY --chown=proxyuser app/script/walletoperations.sh ${HOME}/walletoperations.sh
COPY --chown=proxyuser app/script/confirmation.sh ${HOME}/confirmation.sh
COPY --chown=proxyuser app/config/watcher_btcnode_curlcfg.properties ${HOME}/watcher_btcnode_curlcfg.properties
COPY --chown=proxyuser app/config/spender_btcnode_curlcfg.properties ${HOME}/spender_btcnode_curlcfg.properties
COPY --chown=proxyuser app/config/config.properties ${HOME}/config.properties
COPY --chown=proxyuser app/script/startproxy.sh ${HOME}/startproxy.sh
COPY --chown=proxyuser app/script/trace.sh ${HOME}/trace.sh
COPY --chown=proxyuser app/script/sendtobitcoinnode.sh ${HOME}/sendtobitcoinnode.sh
COPY --chown=proxyuser app/script/responsetoclient.sh ${HOME}/responsetoclient.sh
COPY --chown=proxyuser app/script/importaddress.sh ${HOME}/importaddress.sh
COPY --chown=proxyuser app/script/sql.sh ${HOME}/sql.sh
COPY --chown=proxyuser app/data/watching.sql ${HOME}/watching.sql
COPY --chown=proxyuser app/script/computefees.sh ${HOME}/computefees.sh
COPY --chown=proxyuser app/script/unwatchrequest.sh ${HOME}/unwatchrequest.sh
COPY --chown=proxyuser app/script/getactivewatches.sh ${HOME}/getactivewatches.sh
COPY --chown=proxyuser app/script/utils.sh ${HOME}/utils.sh
COPY --chown=proxyuser app/script/manage_missed_conf.sh ${HOME}/manage_missed_conf.sh
COPY --chown=proxyuser app/script/tests.sh ${HOME}/tests.sh
COPY --chown=proxyuser app/script/tests-cb.sh ${HOME}/tests-cb.sh
COPY --chown=proxyuser app/bin/lightning-cli_x86 ${HOME}/lightning-cli

USER ${USERNAME}
WORKDIR ${HOME}

RUN chmod +x startproxy.sh requesthandler.sh lightning-cli \
 && chmod 600 watcher_btcnode_curlcfg.properties \
 && chmod 600 spender_btcnode_curlcfg.properties \
 && chmod 600 config.properties \
 && mkdir db

VOLUME ["${HOME}/db", "${HOME}/.lightning"]

ENTRYPOINT ["./startproxy.sh"]
