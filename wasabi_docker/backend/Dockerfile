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


WORKDIR /WalletWasabi/WalletWasabi.Backend

RUN dotnet build -c Release -o /app/ -r linux-x64
RUN dotnet publish --output /app/ -c Release --disable-parallel --no-cache /p:DebugType=none /p:DebugSymbols=false /p:ErrorReport=none

FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gpg \
    wget \
    procps \
 && rm -rf /var/lib/apt/lists/*

# install dotnet runtime
RUN wget -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o microsoft.asc.gpg
RUN mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
RUN wget https://packages.microsoft.com/config/debian/11/prod.list
RUN mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
RUN chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg
RUN chown root:root /etc/apt/sources.list.d/microsoft-prod.list
RUN apt-get update && apt-get install -y dotnet-sdk-8.0

COPY --from=builder /app /app

WORKDIR /app

COPY docker-entrypoint.sh docker-entrypoint.sh

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
