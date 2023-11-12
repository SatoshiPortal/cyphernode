FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine3.18 AS builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

# master branch 
RUN git clone --recursive https://github.com/zkSNACKs/WalletWasabi.git /WalletWasabi


WORKDIR /WalletWasabi/WalletWasabi.Backend

RUN dotnet build -c Release -o /app/ -r linux-x64
RUN dotnet publish --output /app/ -c Release --disable-parallel --no-cache /p:DebugType=none /p:DebugSymbols=false /p:ErrorReport=none

FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine3.18

RUN apk add --no-cache --update \
    icu

COPY --from=builder /app /app

WORKDIR /app

COPY docker-entrypoint.sh docker-entrypoint.sh

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

ENTRYPOINT ["/app/docker-entrypoint.sh"]
