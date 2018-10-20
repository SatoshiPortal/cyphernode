FROM node:alpine

RUN apk add --update bash su-exec p7zip && rm -rf /var/cache/apk/*
RUN mkdir -p /app
RUN mkdir /.config
RUN chmod a+rwx /.config

RUN npm install -g yo
COPY generator-cyphernode /app
WORKDIR /app/generator-cyphernode
RUN npm link

WORKDIR /data

ENTRYPOINT ["/sbin/su-exec"]
RUN find / -perm +6000 -type f -exec chmod a-s {} \; || true
