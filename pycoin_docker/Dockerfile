#FROM resin/raspberry-pi-alpine-python:3.6
FROM python:3.6-alpine

ARG USER_ID
ARG GROUP_ID
ENV USERNAME proxyuser
ENV HOME /${USERNAME}
ENV USER_ID ${USER_ID:-1000}
ENV GROUP_ID ${GROUP_ID:-1000}

RUN addgroup -g ${GROUP_ID} ${USERNAME} \
    && adduser -u ${USER_ID} -G ${USERNAME} -D -s /bin/sh -h ${HOME} ${USERNAME}

RUN apk add --update --no-cache git jq \
&& pip install --no-cache-dir pycoin \
&& cd \
&& git clone https://github.com/Kexkey/pycoin.git \
&& cp -rf pycoin/pycoin/* /usr/local/lib/python3.6/site-packages/pycoin

COPY --chown=proxyuser script/pycoin.sh ${HOME}/pycoin.sh
COPY --chown=proxyuser script/requesthandler.sh ${HOME}/requesthandler.sh
COPY --chown=proxyuser script/responsetoclient.sh ${HOME}/responsetoclient.sh
COPY --chown=proxyuser script/startpycoin.sh ${HOME}/startpycoin.sh
COPY --chown=proxyuser script/trace.sh ${HOME}/trace.sh

USER ${USERNAME}
WORKDIR ${HOME}

RUN chmod +x startpycoin.sh requesthandler.sh

ENTRYPOINT ["./startpycoin.sh"]
