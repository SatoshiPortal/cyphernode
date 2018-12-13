FROM alpine:3.8

RUN apk add --update --no-cache curl socat

COPY callbacks_cron /etc/periodic/15min/callbacks_cron

RUN chmod +x /etc/periodic/15min/callbacks_cron

ENTRYPOINT ["crond"]
CMD ["-f"]
