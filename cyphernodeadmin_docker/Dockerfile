FROM golang:1.16-alpine as builder

RUN apk --update add alpine-sdk yarn

RUN git clone https://github.com/schulterklopfer/cyphernode_admin.git /src

WORKDIR /src/ui-src
RUN yarn install && yarn run build

WORKDIR /src

RUN go generate
ENV VERSION=0.1
ENV CODENAME=cyphernode_admin
RUN export DATE=$(date)
RUN CGO_ENABLED=0 GOGC=off go build -ldflags "-s" -a

FROM scratch
COPY --from=builder /src/cyphernode_admin /cyphernode_admin
COPY --from=builder /src/ui-src/build /ui
CMD ["/cyphernode_admin"]