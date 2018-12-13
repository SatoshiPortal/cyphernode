FROM python:3.6-alpine3.8

ENV HOME /pycoin

RUN apk add --update --no-cache git jq su-exec socat \
 && pip install --no-cache-dir pycoin \
 && cd / \
 && git clone https://github.com/Kexkey/pycoin.git \
 && cp -rf pycoin/pycoin/* /usr/local/lib/python3.6/site-packages/pycoin \
 && rm -rf pycoin/*

COPY script/pycoin.sh ${HOME}/pycoin.sh
COPY script/requesthandler.sh ${HOME}/requesthandler.sh
COPY script/responsetoclient.sh ${HOME}/responsetoclient.sh
COPY script/startpycoin.sh ${HOME}/startpycoin.sh
COPY script/trace.sh ${HOME}/trace.sh
COPY script/monitoring.sh ${HOME}/monitoring.sh

WORKDIR ${HOME}

RUN chmod +x startpycoin.sh requesthandler.sh

ENTRYPOINT ["su-exec"]
