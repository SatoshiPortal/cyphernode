FROM alpine:3.12.4

RUN apk add --update --no-cache \
    curl

COPY callbacks_cron /etc/periodic/15min/callbacks_cron

RUN chmod +x /etc/periodic/15min/callbacks_cron

ENTRYPOINT ["crond"]
CMD ["-f"]
