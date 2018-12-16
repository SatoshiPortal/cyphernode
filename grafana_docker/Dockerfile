# Golang build container
FROM golang:1.11-alpine3.8

RUN apk add --update --no-cache build-base

WORKDIR $GOPATH/src/github.com/grafana/grafana

COPY Gopkg.toml Gopkg.lock ./
COPY vendor vendor

ARG DEP_ENSURE=""
RUN if [ ! -z "${DEP_ENSURE}" ]; then \
      go get -u github.com/golang/dep/cmd/dep && \
      dep ensure --vendor-only; \
    fi

COPY pkg pkg
COPY build.go build.go
COPY package.json package.json

RUN go run build.go build

# Node build container
FROM node:8

WORKDIR /usr/src/app/

COPY package.json yarn.lock ./
RUN yarn install --pure-lockfile --no-progress

COPY Gruntfile.js tsconfig.json tslint.json ./
COPY public public
COPY scripts scripts
COPY emails emails

ENV NODE_ENV production
RUN ./node_modules/.bin/grunt build

# Final container
FROM alpine:3.8

ARG GF_UID="472"
ARG GF_GID="472"

ENV PATH=/usr/share/grafana/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
    GF_PATHS_DATA="/var/lib/grafana" \
    GF_PATHS_HOME="/usr/share/grafana" \
    GF_PATHS_LOGS="/var/log/grafana" \
    GF_PATHS_PLUGINS="/var/lib/grafana/plugins" \
    GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

WORKDIR $GF_PATHS_HOME

RUN apk add --update --no-cache ca-certificates shadow bash iputils

#RUN apt-get update && apt-get upgrade -y && \
#    apt-get install -qq -y libfontconfig ca-certificates && \
#    apt-get autoremove -y && \
#    rm -rf /var/lib/apt/lists/*

COPY conf ./conf

RUN mkdir -p "$GF_PATHS_HOME/.aws" && \
    groupadd -r -g $GF_GID grafana && \
    useradd -r -u $GF_UID -g grafana grafana && \
    mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
             "$GF_PATHS_PROVISIONING/dashboards" \
             "$GF_PATHS_LOGS" \
             "$GF_PATHS_PLUGINS" \
             "$GF_PATHS_DATA" && \
    cp "$GF_PATHS_HOME/conf/sample.ini" "$GF_PATHS_CONFIG" && \
    cp "$GF_PATHS_HOME/conf/ldap.toml" /etc/grafana/ldap.toml && \
    chown -R grafana:grafana "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" && \
    chmod 777 "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS"

COPY --from=0 /go/src/github.com/grafana/grafana/bin/linux-amd64/grafana-server /go/src/github.com/grafana/grafana/bin/linux-amd64/grafana-cli ./bin/
COPY --from=1 /usr/src/app/public ./public
COPY --from=1 /usr/src/app/tools ./tools

EXPOSE 3000

#COPY ./packaging/docker/run.sh /run.sh

#USER grafana
#ENTRYPOINT [ "/run.sh" ]
#CMD ["ls", "/"]


ENV TELEGRAF_VERSION 1.9.0
ENV INFLUXDB_VERSION 1.7.1

# Install telegraf and influxdb (# Install influxdb
# https://github.com/influxdata/influxdata-docker/blob/master/telegraf/1.2/Dockerfile
RUN apk add --no-cache iputils ca-certificates
RUN update-ca-certificates
RUN apk add --no-cache --virtual .build-deps wget gnupg tar
RUN gpg --keyserver hkp://ha.pool.sks-keyservers.net --recv-keys 05CE15085FC09D18E99EFB22684A14CF2582E0C5
RUN wget -q https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz.asc
RUN wget -q https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz
RUN gpg --batch --verify telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz.asc telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz
RUN mkdir -p /usr/src /etc/telegraf
RUN tar -C /usr/src -xzf telegraf-${TELEGRAF_VERSION}-static_linux_amd64.tar.gz
RUN mv /usr/src/telegraf*/telegraf.conf /etc/telegraf/
RUN chmod +x /usr/src/telegraf*/*
RUN cp -a /usr/src/telegraf*/* /usr/bin/
RUN rm -rf *.tar.gz* /usr/src /root/.gnupg
RUN apk del .build-deps
EXPOSE 8125/udp 8092/udp 8094
VOLUME ["/etc/telegraf"]


# Install influxdb
# https://github.com/influxdata/influxdata-docker/blob/master/influxdb/1.2/Dockerfile
RUN apk add --no-cache --virtual .build-deps wget gnupg tar ca-certificates && \
    update-ca-certificates && \
    gpg --keyserver hkp://ha.pool.sks-keyservers.net \
        --recv-keys 05CE15085FC09D18E99EFB22684A14CF2582E0C5 && \
    wget -q https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz.asc && \
    wget -q https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    gpg --batch --verify influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz.asc influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    mkdir -p /usr/src && \
    tar -C /usr/src -xzf influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    rm -f /usr/src/influxdb-*/influxdb.conf && \
    chmod +x /usr/src/influxdb-*/* && \
    cp -a /usr/src/influxdb-*/* /usr/bin/ && \
    rm -rf *.tar.gz* /usr/src /root/.gnupg && \
    apk del .build-deps
VOLUME ["/etc/influxdb"]
EXPOSE 8083 8086

# Install supervisord
RUN apk --no-cache add supervisor
COPY supervisord/supervisord.conf /etc/supervisord.conf

# Configuration
COPY telegraf/telegraf.conf /etc/telegraf/telegraf.conf
COPY influxdb/influxdb.conf /etc/influxdb/influxdb.conf

ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]

