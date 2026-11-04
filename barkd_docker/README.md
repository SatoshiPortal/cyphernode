# barkd

Bark wallet daemon for the `ark` feature. Built from the scuttle fork at the
commit pinned in the Dockerfile; override `SCUTTLE_COMMIT` to move it.

The container needs Cyphernode's bitcoind, Bitcoin Core 28 or later with
txindex on, and an Ark server reachable at `ARK_SERVER_URL`. On first boot it
generates a bearer token, waits until bitcoind has finished its initial sync,
creates the wallet, and registers the wallet's own on-chain address as the
fallback payout destination. Back up the datadir: it holds the seed.

```
docker build -t cyphernode/barkd:v0.9.0-dev-local barkd_docker/
```
