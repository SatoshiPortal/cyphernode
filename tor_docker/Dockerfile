FROM alpine:3.12.4 AS builder

ARG TOR_VER=0.4.5.6
ARG TORGZ=https://dist.torproject.org/tor-$TOR_VER.tar.gz

RUN apk --no-cache add --update \
  alpine-sdk gnupg libevent libevent-dev zlib zlib-dev openssl openssl-dev su-exec

RUN wget $TORGZ.asc && wget $TORGZ

# Verify tar signature, build and install
# From https://2019.www.torproject.org/include/keys.txt
# Roger Dingledine: 0xEB5A896A28988BF5, 0xC218525819F78451
# Nick Mathewson: 0xFE43009C4607B1FB, 0x6AFEE6D49E92B601(signing key)
RUN gpg --keyserver keys.openpgp.org --recv-keys 0xFE43009C4607B1FB 0x6AFEE6D49E92B601 \
 && gpg --verify tor-$TOR_VER.tar.gz.asc \
 && tar xfz tor-$TOR_VER.tar.gz && cd tor-$TOR_VER \
 && ./configure && make install

FROM alpine:3.12.4

RUN apk --no-cache add --update \
  su-exec

COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /lib/ /lib/
COPY --from=builder /usr/lib/ /usr/lib/

ENTRYPOINT ["su-exec"]

# docker run -it --rm --network wbnet -v /home/debian/whatever/tor:/tor tor
# wget https://dist.torproject.org/tor-0.4.1.6.tar.gz.asc && wget https://dist.torproject.org/tor-0.4.1.6.tar.gz
