# barkd

Bark wallet daemon for the `ark` feature. Built from the scuttle fork at the
commit pinned in the Dockerfile; override `SCUTTLE_COMMIT` to move it.

The container needs Cyphernode's bitcoind, Bitcoin Core 28 or later with
txindex on, and an Ark server reachable at `ARK_SERVER_URL`. On first boot it
generates a bearer token, waits until bitcoind has finished its initial sync
and creates the wallet. Coins the server pays out at expiry land in the
wallet's own on-chain wallet. Back up the datadir: it holds the seed.

```
docker build -t cyphernode/barkd:v0.9.0-dev-local barkd_docker/
```

## Maintenance

**Restart to prune.** The entrypoint drops the wallet's old coin-state rows
before starting barkd, so a wallet that has become slow at joining rounds
(`last_refresh` in `ark_getinfo` stops advancing, barkd logs "attestation is
invalid" or "Failed to join round") recovers with `docker restart` of the
barkd container.

**Recreate from seed.** When the Ark server has marked coins spent that the
wallet still shows, barkd retries them in every round and never recovers on
its own (`needs_refresh_sat` stays up, every refresh fails "unusable inputs").
A wallet created again from its own seed takes the server's view and
recovers what the server still owes it:

1. Stop barkd. Keep a copy of the datadir.
2. Move the datadir aside and make a new one with only `auth_token` and
   `config.toml` copied from the old one.
3. Start barkd and create the wallet from the seed in the old datadir's
   `mnemonic` file:
   `POST /api/v1/wallet/create` with
   `{"network":"<net>","mnemonic":"<words>","birthday_height":<height>,"force":true}`
   (birthday height: a block before the wallet's first board).
4. The new wallet numbers its movements from 1 again. In Cyphernode's
   database set `ark_history_floor` to `0` and `ark_last_pushed_at` to the
   empty string (`cyphernode_props`), then restart the proxy. Receives
   already called back keep their rows; a new movement that reuses an old
   movement id for the same watched address is not called back again.

Do both on a quiet wallet: no sends, boards or offboards in flight.
