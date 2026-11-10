# Cyphernet Bitcoin Core and Core Lightning

This branch connects Bitcoin Core 32.1 and Core Lightning to Cyphernet, the custom signet with a 30-second difficulty target. It uses the challenge `0014dc9786c6b1c3ad2bcc45014b40384fba3419de17` and bootstraps from `170.75.166.64:38333`. The block subsidy and halving interval remain Bitcoin's normal 50 BTC and 210,000 blocks.

The Bitcoin image is built from the pinned Bitcoin Core v32.1 commit plus [the small signet spacing patch](docker/bitcoin/cyphernet-core.patch). The image is tagged `cyphernet/bitcoin-core:32.1`. Core Lightning runs with `network=signet` against that Core node, and DNS peer discovery is disabled so it does not try public signet peers. Connect only to Lightning peers that also use Cyphernet.

## Launch

Clone this branch and run:

```bash
CYPHERNET_PUBLIC_HOST=your.public.ip ./cyphernet/start.sh
```

`CYPHERNET_PUBLIC_HOST` is optional; set it when you want Core Lightning to announce a public address. The script creates `cyphernet/data/` on first run and preserves its configuration and RPC password on later runs. To use another data directory, set `CYPHERNET_DATA_DIR` before running. It publishes Bitcoin P2P on TCP 38333 and Core Lightning on TCP 9735; Bitcoin RPC stays inside the Docker network.

This launcher runs the two node daemons. The existing Cyphernode API installer is not part of this path; its watch endpoints still use legacy wallet RPCs that need a separate migration for Bitcoin Core 32.1.

Check status with:

```bash
docker compose -p cyphernet -f cyphernet/compose.yaml exec bitcoin bitcoin-cli -datadir=/bitcoin getblockchaininfo
docker compose -p cyphernet -f cyphernet/compose.yaml exec core-lightning lightning-cli --lightning-dir=/.lightning --signet getinfo
```

Back up the Bitcoin data directory and Core Lightning directory together. In particular, Core Lightning's `hsm_secret` is required to recover its identity and channels. A fresh installation can resync the public chain, but it cannot recover a lost Lightning node identity or channel state without those files.
