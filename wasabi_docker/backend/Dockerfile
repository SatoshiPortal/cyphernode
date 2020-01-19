FROM mcr.microsoft.com/dotnet/core/sdk:3.1-alpine AS builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN apk add --no-cache git

RUN git clone --recursive https://github.com/zkSNACKs/WalletWasabi.git /WalletWasabi
WORKDIR /WalletWasabi
# commit where rpc was added. Prevent break by upgrade of source
RUN git checkout eb318b8dcfe06870be768d2c9670fa7ff343d1aa

COPY patches/Program.patch .
RUN patch WalletWasabi.Backend/Program.cs -i Program.patch
RUN rm Program.patch

WORKDIR /WalletWasabi/WalletWasabi.Backend

RUN dotnet build -c Release -o /app/ -r linux-x64
RUN dotnet publish --output /app/ -c Release --disable-parallel --no-cache /p:DebugType=none /p:DebugSymbols=false /p:ErrorReport=none

FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-alpine

RUN apk add --no-cache --update \
    icu

COPY --from=builder /app /app

WORKDIR /app

COPY docker-entrypoint.sh docker-entrypoint.sh

# Do not run as root user
#RUN chown -R whateveruser:whateveruser /app
#USER whateveruser

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

ENTRYPOINT ["/app/docker-entrypoint.sh"]
