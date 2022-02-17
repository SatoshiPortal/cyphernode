# Cyphernode v0.8.0

Say hello to PostgreSQL!  We moved from SQLite3 to PostgreSQL to take advantage of its enterprise-class features.  Here are some of our motivations:

- Better overall performance
- Easier to implement replicas / distributed redundancy
- Running in an independent container: can be used by other containers as well
- More/better administration tools
- Easier to configure C-lightning to use PostgreSQL
- Future development

All of that may also be possible with SQLite3, but with a lot more work.

If you have an existing Cyphernode installation with existing data, Cyphernode will take care of the migration: we built all the required ETL scripts that will hopefully flawlessly move your current instance to the new DBMS.

There are also several improvements and new features in this release.  Thanks go to [@pablof7z](https://twitter.com/pablof7z) @phillamy and @schulterklopfer for their valuable contributions, feedbacks and inputs!

## New features

- PostgreSQL: migrating from SQLite3 to PostgreSQL
  - Automatic migration from current SQLite3 to new PostgreSQL (ETL)
  - New Indexes
  - Separate container
- Support for labels when:
  - watching addresses
  - getting new addresses
- New `ln_paystatus` endpoint
- New `validateaddress` endpoint
- New `deriveindex_bitcoind` endpoint (20x faster than Pycoin), also supports ypub/upub and zpub/vpub notations!
- New `derivepubpath_bitcoind` (20x faster than Pycoin), also supports ypub/upub and zpub/vpub notations!

## Fixes and improvements

- Refactoring of _manage_missed_conf_ and _confirmation management_
- `ln_pay` now first pays using `legacy_pay` (MPP disabled) and on failure (for routing reasons), retry with the `pay` plugin (MPP enabled by default)
- Small fixes in `ln_pay`
- Small fixes in `ln_delinvoice`
- Small fixes in `ln_connectfund`
- Small fixes in LN webhooks
- `ln_listpays` can now take a `bolt11` string argument
- Sometimes, Gatekeeper was not compliant to JWT: now it is but still compatible with previous buggy version
- Fixed CN client examples
- Gatekeeper now returns _401 Unauthorized_ on authentication error and _403 Forbidden_ on authorization error
- Gatekeeper now waits for the Proxy to be ready before listening to requests
- More graceful shutdown on certain containers
- Docker now uses the `helloworld` endpoint to check Proxy's health
- Better way to determine slow machine during setup
- Better tests when starting up
- Fixed a bug when running Cyphernode as current user instead of dedicated user
- When trying to add a batcher that already exists (same `label`), it will now modify existing one
- Got rid of the full rawtx from the database!  Let's use Bitcoin Core if needed
- `helloworld` endpoint now returns a JSON compliant response
- Added and improved tests:
  - api_auth_docker/tests/test-gatekeeper.sh
  - proxy_docker/app/tests/test-manage-missed.sh
  - proxy_docker/app/tests/test-batching.sh
  - proxy_docker/app/tests/test-derive.sh
  - proxy_docker/app/tests/test-watchpub32.sh
  - proxy_docker/app/tests/test-watches.sh
- Fixed typos and improved clarity in messages
- Bump ws from 5.2.2 to 5.2.3 in /cyphernodeconf_docker
- Bump path-parse from 1.0.6 to 1.0.7 in /cyphernodeconf_docker
- Bump tmpl from 1.0.4 to 1.0.5 in /cyphernodeconf_docker
- Bump validator from 10.11.0 to 13.7.0 in /cyphernodeconf_docker
- Code cleaning

## Upgrades

- C-lightning from v0.10.0 to v0.10.2
- Bitcoin Core from v0.21.1 to v22.0

## Cypherapps

- Batcher from v0.1.2 to v0.2.0
- Spark Wallet from v0.2.17 to v0.3.0
- Specter from v1.3.1 to v1.7.1
