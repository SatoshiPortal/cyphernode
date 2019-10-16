FROM mcr.microsoft.com/dotnet/core/sdk:3.0-alpine3.9 AS builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN apk add --no-cache git

#RUN git clone --recursive https://github.com/zkSNACKs/WalletWasabi.git /WalletWasabi
RUN git clone --recursive --branch Features/Rpc-Server https://github.com/lontivero/Wasabito.git /WalletWasabi

WORKDIR /WalletWasabi

COPY backend/patches/ITxStoreOperation.patch .
RUN patch WalletWasabi/Transactions/Operations/ITxStoreOperation.cs -i ITxStoreOperation.patch
RUN rm ITxStoreOperation.patch

COPY backend/patches/PenaltyFactory.patch .
RUN patch WalletWasabi/Gma/QrCodeNet/Encoding/Masking/Scoring/PenaltyFactory.cs -i PenaltyFactory.patch
RUN rm PenaltyFactory.patch

COPY backend/patches/PatternFactory.patch .
RUN patch WalletWasabi/Gma/QrCodeNet/Encoding/Masking/PatternFactory.cs -i PatternFactory.patch
RUN rm PatternFactory.patch

COPY backend/patches/IndexBuilderService.patch .
RUN patch WalletWasabi/Services/IndexBuilderService.cs -i IndexBuilderService.patch
RUN rm IndexBuilderService.patch

COPY WalletGenerator /WalletGenerator

WORKDIR /WalletGenerator

RUN dotnet build -c Release -o /app/ -r linux-x64 /p:langversion=8.0
RUN dotnet publish --output /app/ -c Release --disable-parallel --no-cache /p:DebugType=none /p:DebugSymbols=false /p:ErrorReport=none /p:langversion=8.0

WORKDIR /WalletWasabi/WalletWasabi.Gui

RUN dotnet build -c Release -o /app/ -r linux-x64 /p:langversion=8.0
RUN dotnet publish --output /app/ -c Release --disable-parallel --no-cache /p:DebugType=none /p:DebugSymbols=false /p:ErrorReport=none /p:langversion=8.0

# remove unused files
#RUN rm /app/TorDaemons/tor-osx64.zip /app/TorDaemons/tor-win32.zip
RUN rm -rf /app/TorDaemons
RUN rm -rf /app/runtimes/osx /app/runtimes/tizen-armel /app/runtimes/tizen-x86 /app/runtimes/win /app/runtimes/win-x64 /app/runtimes/win--x86
RUN rm -rf /app/Hwi/Software/hwi-osx64.zip /app/Hwi/Software/hwi-win64

FROM mcr.microsoft.com/dotnet/core/runtime:2.2-alpine3.9

ENV APPDATA=/root/.walletwasabi/client

RUN apk add --no-cache --update \
    expect \
    tor \
    icu \
 && mkdir -p ${APPDATA}/Wallets/

COPY --from=builder /app /app

WORKDIR /app

ADD scripts scripts
COPY docker-entrypoint.sh docker-entrypoint.sh
COPY torrc /etc/tor/torrc

# Do not run as root user
#RUN chown -R www-data:www-data /app /wasabi
#USER whateveruser

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

ENTRYPOINT ["/app/docker-entrypoint.sh"]
