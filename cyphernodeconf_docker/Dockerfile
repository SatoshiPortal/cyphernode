FROM golang:1.13.15-alpine3.12 as builder-go

RUN apk add git build-base

# torgen
RUN mkdir -p /go/src/torgen
COPY torgen/torgen.go /go/src/torgen
WORKDIR /go/src/torgen
RUN go get && go build torgen.go && chmod +x /go/src/torgen/torgen

# cam
RUN git clone https://github.com/SatoshiPortal/cam.git /go/src/github.com/SatoshiPortal/cam
WORKDIR /go/src/github.com/SatoshiPortal/cam
RUN go get && ./build.sh && chmod +x ./cam

FROM alpine:3.12.4 as builder-qrencode

RUN apk add --update --no-cache \
    autoconf \
    automake \
    build-base \
    libtool \
    git \
    pkgconfig

RUN git clone -b v4.1.0 https://github.com/fukuchi/libqrencode.git \
 && cd libqrencode \
 && ./autogen.sh \
 && ./configure \
 && make \
 && make install

FROM node:15.11.0-alpine3.12

ENV EDITOR=/usr/bin/nano

COPY . /app
COPY --from=builder-go /go/src/torgen/torgen /app/torgen
COPY --from=builder-go /go/src/github.com/SatoshiPortal/cam /app/cam

COPY --from=builder-qrencode /usr/local/bin/qrencode /usr/local/bin/
COPY --from=builder-qrencode /usr/local/lib/libqrencode.so.4.1.0 /usr/local/lib/libqrencode.so.4

WORKDIR /app

RUN mkdir /data && \
  apk add --update su-exec p7zip openssl nano apache2-utils git && \
  rm -rf /var/cache/apk/* && \
  npm ci --production

WORKDIR /app

ENTRYPOINT ["/sbin/su-exec"]

