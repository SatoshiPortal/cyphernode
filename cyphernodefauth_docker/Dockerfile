FROM golang:1.16-alpine as builder

RUN apk --update add alpine-sdk

RUN git clone https://github.com/schulterklopfer/cyphernode_fauth.git /src

WORKDIR /src

RUN go generate
ENV VERSION=0.1
ENV CODENAME=cyphernode_fauth
RUN export DATE=$(date)
RUN CGO_ENABLED=0 GOGC=off go build -ldflags "-s" -a

FROM scratch
COPY --from=builder /src/cyphernode_fauth /cyphernode_fauth
CMD ["/cyphernode_fauth"]
