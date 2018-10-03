FROM alpine

RUN apk add --update --no-cache \
    curl \
    dialog

RUN mkdir /volume /script /data

WORKDIR /script

ENV TRACING=1

CMD ["./configure.sh"]
