# Cyphernode v0.9.0

This release is mostly performance improvements and software upgrades.

This release contributors: @phillamy and @kexkey


## New

- `bitcoin_gettxoutproof` endpoint
- `bitcoin_generatetoaddress` endpoint


## Improvements

- More and better tests
- Configured Bitcoin network and port are now available in installation info (displayed in the Welcome app)
- Containers environment variables are now segregated in separate env files instead of directly in docker-compose file
- Wallet events (walletnotify) are now published to a MQTT's topic and handled much better
- On tx event, tx information is now sent to Cyphernode by the Bitcoin Node instead of being pulled by Cyphernode
- Block events (blocknotify) are now published to a MQTT's topic and handled much better
- On block event, block information is now sent to Cyphernode by the Bitcoin Node instead of being pulled by Cyphernode
- In regtest, blocks are mined on startup when there's no funds in spending wallet
- Now serving HTTP (instead of self-signed HTTPS) when traefik is accessed via Tor
- Proxy container now Debian-based
- Removed deprecated legacypay from ln_pay
- 60-sec timeout on locks when processing new tx confirmations
- Upgraded Postgresql to 13
- Upgraded Traefik from 1.7 to 2.6
- Upgraded Tor from 0.4.5.6 to 0.4.7.8
- Upgraded Bitcoin Core from v22.0 to v24.0.1
- Upgraded Core Lightning from v0.10.2 to v22.11.1
- Upgraded Spark Wallet from v0.3.0 to v0.3.1
- Upgraded Batcher from v0.2.0 to v0.2.1
- Upgraded Specter from v1.7.1 to v1.14.2


## Fixes

- Minor fixes here and there
