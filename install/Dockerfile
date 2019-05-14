FROM node:11.1-alpine

RUN apk add --update bash su-exec p7zip openssl nano apache2-utils git && rm -rf /var/cache/apk/*
RUN mkdir -p /app
RUN mkdir /.config
RUN chmod a+rwx /.config

# Workaround for https://github.com/npm/uid-number/issues/3
RUN NPM_CONFIG_UNSAFE_PERM=true npm install -g yo
COPY generator-cyphernode /app
WORKDIR /app/generator-cyphernode
RUN npm link

WORKDIR /data

ENV EDITOR=/usr/bin/nano

ENTRYPOINT ["/sbin/su-exec"]
RUN find / -perm +6000 -type f -exec chmod a-s {} \; || true
