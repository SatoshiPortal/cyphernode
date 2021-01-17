FROM golang:1.14-alpine as builder

RUN apk --update add alpine-sdk bash curl yarn git

RUN git clone https://github.com/schulterklopfer/cyphernode_admin.git /src

WORKDIR /src

WORKDIR /src/ui-src
RUN yarn install && yarn run build

WORKDIR /src
RUN go generate
#ENV VERSION=0.1
#ENV CODENAME=cyphernodeadmin
#RUN export DATE=$(date)
#RUN CGO_ENABLED=1 GOGC=off go build -ldflags "-s" -a
RUN go build -ldflags "-s -w"

FROM alpine

RUN mkdir /app

COPY --from=builder /src/cyphernode_admin /app/cyphernode_admin
COPY --from=builder /src/ui-src/build /ui

WORKDIR /data

CMD ["/app/cyphernode_admin"]
