FROM mcr.microsoft.com/dotnet/sdk:7.0 as builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN apt update && apt install -y --no-install-recommends git

# v2.0.4 branch
RUN git clone --single-branch --branch v2.0.4 --recursive https://github.com/zkSNACKs/WalletWasabi.git /WalletWasabi

WORKDIR /WalletWasabi

RUN dotnet restore "WalletWasabi.Daemon/WalletWasabi.Daemon.csproj"

WORKDIR /WalletWasabi/WalletWasabi.Daemon

RUN dotnet build "WalletWasabi.Daemon.csproj" -c Release -o /app/build
RUN dotnet publish "WalletWasabi.Daemon.csproj" -c Release -o /app/publish


FROM mcr.microsoft.com/dotnet/aspnet:7.0

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

COPY --from=builder /app/publish /app

WORKDIR /app

ADD scripts scripts
COPY docker-entrypoint.sh docker-entrypoint.sh

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

# Configure Tor
RUN echo "SocksPort 127.0.0.1:37150\nControlPort 37151\nCookieAuthentication 1" > /etc/tor/torrc

ENTRYPOINT ["/app/docker-entrypoint.sh"]
