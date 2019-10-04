FROM mcr.microsoft.com/dotnet/core/sdk:2.2-alpine3.8 AS builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN apk add --no-cache git

#RUN git clone --recursive https://github.com/zkSNACKs/WalletWasabi.git /WalletWasabi
RUN git clone --recursive --branch Features/Rpc-Server https://github.com/lontivero/Wasabito.git /WalletWasabi

WORKDIR /WalletWasabi/WalletWasabi.Backend

RUN dotnet restore
RUN dotnet build -c Release -o /app/ -r linux-x64
RUN dotnet publish --output /app/ -c Release --disable-parallel --no-cache /p:DebugType=none /p:DebugSymbols=false /p:ErrorReport=none

FROM mcr.microsoft.com/dotnet/core/aspnet:2.2-alpine3.8

ENV HOME=/root
RUN apk add --no-cache icu nginx

COPY --from=builder /app /app

COPY default.conf /etc/nginx/conf.d/default.conf
RUN mkdir -p /run/nginx

WORKDIR /app

COPY docker-entrypoint.sh docker-entrypoint.sh

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

ENTRYPOINT ["/app/docker-entrypoint.sh"]
