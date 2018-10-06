FROM node:alpine

RUN apk add --update bash && rm -rf /var/cache/apk/*
RUN adduser -D -h /yo yo yo
RUN chown -R yo:yo /usr/local/lib/node_modules /usr/local/bin

USER yo
RUN npm install -g yo
COPY generator-cyphernode /yo
WORKDIR /yo/generator-cyphernode
RUN npm link

USER root
RUN mkdir -p /yo/.config/insight-nodejs

# prevent "do you want to send stats"-questions for temporary yo installation
COPY insight-yo.json /yo/.config/insight-nodejs/insight-yo.json
RUN chown -R yo:yo /yo/.config

# run in user space
USER yo
WORKDIR /yo

CMD ["yo","cyphernode"]

