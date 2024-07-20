FROM mcr.microsoft.com/dotnet/sdk:8.0 as builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN apt update && apt install -y --no-install-recommends git

# v2.0.7.1 tag
RUN git clone --single-branch --branch v2.0.7.1 --recursive https://github.com/zkSNACKs/WalletWasabi.git /WalletWasabi

WORKDIR /WalletWasabi

# COPY patches/minOutputAmounts.diff .
# RUN git apply minOutputAmounts.diff
# RUN rm minOutputAmounts.diff

RUN dotnet restore "WalletWasabi.Backend/WalletWasabi.Backend.csproj"

WORKDIR /WalletWasabi/WalletWasabi.Backend

RUN dotnet build "WalletWasabi.Backend.csproj" -c Release -o /app/build
RUN dotnet publish "WalletWasabi.Backend.csproj" -c Release -o /app/publish


FROM mcr.microsoft.com/dotnet/aspnet:8.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gpg \
    wget \
    procps \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/publish /app

WORKDIR /app

COPY docker-entrypoint.sh docker-entrypoint.sh

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT false
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
