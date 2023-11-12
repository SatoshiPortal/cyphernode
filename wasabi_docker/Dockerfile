FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine3.18 AS builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN apk add --no-cache git patch

# master branch
RUN git clone --recursive https://github.com/zkSNACKs/WalletWasabi.git /WalletWasabi

WORKDIR /WalletWasabi

# this patch is really only needed if we are using the externally running Tor
# so we can pass in external IP / port details
# but now we let each wasabi instance run its own Tor for separate identities
COPY patches/TorSettings.patch .
RUN patch WalletWasabi/Tor/TorSettings.cs -i TorSettings.patch
RUN rm TorSettings.patch

WORKDIR /WalletWasabi/WalletWasabi.Daemon

RUN dotnet build "WalletWasabi.Daemon.csproj" -c Release -o /app/build -r linux-x64
RUN dotnet publish "WalletWasabi.Daemon.csproj" -c Release -o /app/ --disable-parallel --no-cache /p:DebugType=none /p:DebugSymbols=false /p:ErrorReport=none

# remove unused files
RUN rm -rf /app/runtimes/osx /app/runtimes/osx-x64 /app/runtimes/osx-arm64 /app/runtimes/tizen-armel /app/runtimes/tizen-x86 /app/runtimes/win /app/runtimes/win-x64 /app/runtimes/win-x86 /app/runtimes/win-arm64 /app/runtimes/win-arm
RUN rm -rf /app/Microservices/Binaries/osx64 /app/Microservices/Binaries/win64
RUN rm -rf /app/Microservices/Binaries/lin64/bitcoind /app/Microservices/Binaries/lin64/hwi

FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine3.18

ENV APPDATA=/root/.walletwasabi/client

RUN apk add --no-cache --update \
    gcompat \
    expect \
    icu \
    curl \
    jq \
 && mkdir -p ${APPDATA}/Wallets/

COPY --from=builder /app /app

WORKDIR /app

ADD scripts scripts
COPY docker-entrypoint.sh docker-entrypoint.sh

# Do not run as root user
#RUN chown -R www-data:www-data /app /wasabi
#USER whateveruser

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

ENTRYPOINT ["/app/docker-entrypoint.sh"]
