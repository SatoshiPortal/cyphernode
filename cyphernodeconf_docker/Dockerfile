FROM golang:1.13-alpine3.10 as builder

RUN apk add git build-base

RUN mkdir -p /go/src/torgen

COPY torgen/torgen.go /go/src/torgen

WORKDIR /go/src/torgen

RUN go get

RUN go build torgen.go
RUN chmod +x /go/src/torgen/torgen

FROM node:12.2.0-alpine

ENV EDITOR=/usr/bin/nano

COPY . /app
COPY --from=builder /go/src/torgen/torgen /app/torgen
WORKDIR /app

RUN mkdir /data && \
  apk add --update su-exec p7zip openssl nano apache2-utils git && \
  rm -rf /var/cache/apk/* && \
  npm ci --production

WORKDIR /app

ENTRYPOINT ["/sbin/su-exec"]

