# cyphernode
Modular Bitcoin full-node microservices API server architecture and utilities toolkit to build scalable, secure and featureful apps and services without trusted third parties. 

# What is cyphernode?

An open-source self-hosted API which allows you to spawn and call your encrypted overlay network of dockerized Bitcoin and crypto software projects (virtual machines).

You can use it to build Bitcoin services and applications using your own Bitcoin and Lightning Network full nodes.

It is an alternative to hosted services and commercial Bitcoin APIs such as Blockchain.info, Bitpay, Coinbase, Blocypher, Bitgo, etc.

It is a substitute for the Bitcore and Insight software projects.

If aims to offer all advanced features and utilities necessary to operate entreprise grade Bitcoin services.  We provide a curated list of functions using multiple software, but you can build your own private ones or add yours as a default option in the project.

It is designed to be deployed on multiple Rasberry Pi with very low computing ressources (and extremely low if installing pre-synchronized blockchain and pruned). Because of the modular architecture, heavier modules like blockchain indexers are optional (and not needed for most commercial use-cases).

Hardware wallets (ColdCard, Trezor) will be utilized for key generation and signing (using PSBT BIP174), as well as for connecting to self-hosted web user interfaces.

It is currently in production by Bylls.com, Canada's first and largest Bitcoin payment processor, as well as Bitcoin Outlet, a fixed-rate Bitcoin exchange service alternative to Coinbase which allows Canadians to purchase bitcoins sent directly to their own Bitcoia wallet.

The project is in **heavy development** - we are currently looking for review, new features, user feedback and contributors to our roadmap.

# About this project

- Created and maintained by www.satoshiportal.com
- Dedicated full-time developper @kexkey
- Project manager @FrancisPouliot
- Disclaimer: as of release on Sept. 23 2018 the project is still it its early stages (Alpha) and many of the features have yet to be implemented. The core architecture and basic wallet operations and blockchain query functions are fully functional.

# How to use cyphernode?

The core component of cyphernode is a request handler which exposes HTTP endpoints via REST API, acting as an absctration layer between your apps and the open-source Bitcoin sofware you want to interact with.

## When calling a cyphernode endpoint, you are either

- making a delegated request (call) to the functions of the P2P network nodes part of your overlay network (e.g. calling Bitcoin RPC)
- directly using scripts and functions with your data, parameters and configs (e.g. derive segwit addresses from Master Public Key, interacting with C-Lightning command line to create and pay a Bolt11 invoice, stamp and verify a file using OpenTimestamps, etc.)
- executing one of the custom script (function) which will make multiple requests to multiple docker containers based on the desired outcome (e.g. add transctions to a batch, sign and broadcast according to your custom schedule).
- changing the configurations and parameters of the underlying sofware or the request dispatcher (e.g. choose derivation path, decide which docker containers you will be using).
- deploying and activating components like the cron container which schedules certain tasks/calls.
- create webhooks with active watch so that your app receives notifications via asynchronous callback

## Make a custom backend for your app by adding your own modules and functions

- Make your own cyphernode by adding any compatible docker container (e.g. Bitcoin-js, electrum personal server, block explorer index)
- Creating custom scripts based on the features of the docerkized software
- Create and add web-interface applications to your docker swarm.
 Your own web wallet (remote control with GUI over your nodes), graphana stats dashboard, reporting, notifications.

# Roadmap/TODO

## Utilities and API endpoints

1. Add opentimestamps endpoints to stamp data, verify, upgrade, get information of OTS files
2. Lightning network callbacks for payment notifications
3. Address identification and validation scripts
- Be able to detect if a given data is a Bitcoin address, P2SH address, Bech32 address, Bolt11 invoice
- Validate according to the type
4. Add blockchain indexer to enable bitcoin block explorer features
5. Add Electrum Personal Server and Electrum Server dockers
- By default, Electrum Personal Server is added to the container network
6.Create endpoints for all delegated tasks
- Add all Bitcoin RPC endpoints
7. Add PGP library docker and endpoints for various signatures
- Cleartext signatures
8. Add "deriveandwatch" script which derives a set of addresses and sends payment notifications
- custom gap limit with 100 as default
9. Add PayNyms library and endpoint
10. Create launch scripts.

## Related tools

1. Open-source (white-label) web interface (self-hosted as part of the default Docker network)
- Allow users to connect using Trezor
- Send PSBT files to ColdCard wallet for remote signing
- Change Bitcoin and C-Lighning configs.
- Manually call all API endpoints (with parameters) in web-interface to empower non-technical users to perform advanced functions
- Complete web-interface over Bitcoin Core RPC
- View transactions, balances, etc.
- suggestions welcome!
2. Lunanode launcher web app

# Example use-case for cyphernode

When building cyphernode, we had specific use-cases in mind that we built for ourselves. Use this as inspiration, and innovate on our procedures.

[See one of Satoshi Portal's use case flow](doc/SATOSHIPORTAL-WORKFLOW.md)

# Contributions

[See contributing document](CONTRIBUTING.md)
