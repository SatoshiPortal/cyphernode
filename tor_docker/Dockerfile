FROM alpine:3.15.4 AS builder

ARG TOR_VER=0.4.7.8
ARG TOR_DIR=tor-$TOR_VER
ARG TOR_FILE=$TOR_DIR.tar.gz
ARG TOR_DIST=https://dist.torproject.org/$TOR_FILE

RUN apk --no-cache add --update \
  alpine-sdk gnupg libevent libevent-dev zlib zlib-dev openssl openssl-dev su-exec

RUN wget $TOR_DIST.sha256sum && wget $TOR_DIST.sha256sum.asc && wget $TOR_DIST

RUN sed -r 's/(.) tor/\1 tor/' tor-0.4.7.8.tar.gz.sha256sum | sha256sum -c -

RUN gpg --auto-key-locate nodefault,wkd --locate-keys ahf@torproject.org  dgoulet@torproject.org nickm@torproject.org \
 && gpg --verify tor-$TOR_VER.tar.gz.sha256sum.asc \
 && tar xfz $TOR_FILE && cd $TOR_DIR \
 && ./configure && make install

FROM alpine:3.15.4

RUN apk --no-cache add --update \
  su-exec

COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /lib/ /lib/
COPY --from=builder /usr/lib/ /usr/lib/

ENTRYPOINT ["su-exec"]