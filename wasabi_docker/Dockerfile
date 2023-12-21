FROM debian:bullseye-slim as builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN apt-get update && apt-get install -y --no-install-recommends wget git patch ca-certificates gpg

# install dotnet sdk
RUN wget -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o microsoft.asc.gpg
RUN mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
RUN wget https://packages.microsoft.com/config/debian/11/prod.list
RUN mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
RUN chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg
RUN chown root:root /etc/apt/sources.list.d/microsoft-prod.list
RUN apt-get update && apt-get install -y dotnet-sdk-8.0

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

FROM debian:bullseye-slim

ENV APPDATA=/root/.walletwasabi/client

RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    curl \
    jq \
    ca-certificates \
    gpg \
    wget \
    procps \
    tor \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p ${APPDATA}/Wallets/

# install dotnet runtime
RUN wget -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o microsoft.asc.gpg
RUN mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
RUN wget https://packages.microsoft.com/config/debian/11/prod.list
RUN mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
RUN chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg
RUN chown root:root /etc/apt/sources.list.d/microsoft-prod.list
RUN apt-get update && apt-get install -y dotnet-runtime-8.0

COPY --from=builder /app /app

WORKDIR /app

ADD scripts scripts
COPY docker-entrypoint.sh docker-entrypoint.sh

# Do not run as root user
#RUN chown -R www-data:www-data /app /wasabi
#USER whateveruser

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

# Configure Tor
RUN echo "SocksPort 127.0.0.1:37150\nControlPort 37151\nCookieAuthentication 1" > /etc/tor/torrc

ENTRYPOINT ["/app/docker-entrypoint.sh"]
