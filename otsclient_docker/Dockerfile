FROM alpine:3.9 as builder

RUN apk add --no-cache --update alpine-sdk bsd-compat-headers \
 && git clone https://github.com/Kexkey/proxychains-ng.git

RUN cd /proxychains-ng \
 && ./configure \
 && make \
 && make install \
 && make install-config

FROM node:11.1-alpine

RUN apk add --update --no-cache \
    git \
    jq \
    su-exec \
 && git clone https://github.com/opentimestamps/javascript-opentimestamps.git \
 && cd javascript-opentimestamps \
# Handle 'Error: could not get uid/gid'
# See: https://github.com/npm/uid-number/issues/3
 && npm config set unsafe-perm true \
 && npm install -g

WORKDIR /script

COPY --from=builder /usr/local/etc/proxychains.conf /usr/local/etc/proxychains.conf
COPY --from=builder /usr/local/bin/proxychains4 /usr/local/bin/proxychains4
COPY --from=builder /usr/local/lib/libproxychains4.so /usr/local/lib/libproxychains4.so

COPY script/otsclient.sh /script/otsclient.sh
COPY script/requesthandler.sh /script/requesthandler.sh
COPY script/responsetoclient.sh /script/responsetoclient.sh
COPY script/startotsclient.sh /script/startotsclient.sh
COPY script/trace.sh /script/trace.sh

RUN chmod +x /script/startotsclient.sh /script/requesthandler.sh

ENTRYPOINT ["su-exec"]
