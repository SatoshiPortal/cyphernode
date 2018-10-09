FROM alpine as builder

RUN set -x\
 && apk add --no-cache\
  gcc\
  make\
  git\
  musl-dev

RUN git clone https://github.com/ncopa/su-exec.git /su-exec

WORKDIR /su-exec
RUN make
RUN strip su-exec

FROM node:alpine

COPY --from=builder /su-exec/su-exec /sbin/

RUN apk add --update bash && rm -rf /var/cache/apk/*
RUN mkdir -p /app
RUN mkdir /.config
RUN chmod a+rwx /.config

RUN npm install -g yo
COPY generator-cyphernode /app
WORKDIR /app/generator-cyphernode
RUN npm link

WORKDIR /data

ENTRYPOINT ["/sbin/su-exec"]
