FROM eclipse-mosquitto:1.6-openssl

ENV HOME /notifier

RUN apk --no-cache --update add jq curl su-exec

WORKDIR ${HOME}

COPY script/* ./

RUN chmod +x startnotifier.sh requesthandler.sh \
 && chmod o+w .

ENTRYPOINT ["su-exec"]

# docker run --rm -d -p 1883:1883 -p 9001:9001 --network cyphernodenet --name broker eclipse-mosquitto
# docker run --rm -it --network cyphernodenet --name mq1 mqtt-client
