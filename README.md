# cyphernode

Modular Bitcoin full-node microservices API server architecture and utilities toolkit to build scalable, secure and featureful apps and services without trusted third parties.

# What is cyphernode?

Cyphernode is a Free open-source alternative to hosted services and commercial Bitcoin APIs such as Blockchain.info, Bitpay, Coinbase, BlockCypher, Bitgo, etc. You can use it to build Bitcoin services and applications using your own Bitcoin and Lightning Network full nodes. It is a substitute for the Bitcore and Insight software projects.

It implements a self-hosted API which allows you to spawn and call your encrypted overlay network of dockerized Bitcoin and crypto software projects (virtual machines). The Docker containers used in this project are hosted at www.bitcoindockers.com.

It aims to offer all advanced features and utilities necessary to operate entreprise-grade Bitcoin services.  It includes a curated list of functions using multiple software, but you can build your own private ones or add yours as a default option in the project.

It is currently in production by Bylls.com, Canada's first and largest Bitcoin payment processor, as well as Bitcoin Outlet, a fixed-rate Bitcoin exchange service alternative to Coinbase which allows Canadians to purchase bitcoins sent directly to their own Bitcoin wallet.

The project is in **heavy development** - we are currently looking for reviews, new features, user feedback and contributors to our roadmap.

![image](doc/CN-Arch.jpg)

# Low requirements, efficient use of resources

Cyphernode is designed to be deployed on virtual machines with launch scripts, but with efficiency and minimalism in mind so that it can also run on multiple Rasberry Pi with very low computing ressources (and extremely low if installing pre-synchronized blockchain and pruned). Because of the modular architecture, heavier modules like blockchain indexers are optional (and not needed for most commercial use-cases).

* For a full-node and all modules:
  * 350 GB of storage, 2GB of RAM.
* Hardware wallets (ColdCard, Trezor) for key generation and signing (using PSBT BIP174), as well as for connecting to self-hosted web user interfaces.

# Cyphernode Architecture
Cyphernode is an assembly of Docker containers being called by a request dispatcher.

The request dispatcher (requesthandler.sh) is the HTTP entry point.
The request dispatcher is stateful: it keeps some data to be more effective on next calls.
The request dispatcher is where Cyphernode scales with new features: add your switch, dispatch requests to your stuff.
We are trying to construct each container so that it can be used separately, as a standalone reusable component.

Important to us:

Be as optimized as possible, using Alpine when possible and having the smallest Docker image size possible
Reuse existing software: built-in shell commands, well-established pieces of software, etc.
Use open-source software
Don't reinvent the wheel
Expose the less possible surface
Center element: proxy_docker
The proxy_docker is the container receiving and dispatching calls from clients. When adding a feature to Cyphernode, it is the first part to be modified to integrate the new feature.

proxy_docker/app/script/requesthandler.sh
You will find in there the switch statement used to dispatch the requests. Just add a case block with your command, using other cases as examples for POST or GET requests.

proxy_docker/app/config
You will find there config files. config.properties should be used to centralize configs. spender and watcher properties are used to obfuscate credentials on curl calls.

proxy_docker/app/data
watching.sql contains the data model. Called "watching" because in the beginning of the project, it was only used for watching addresses. Now could be used to index the blockchain (build an explorer) and add more features.

cron_docker
If you have jobs to be scheduled, use this container. Just add an executable and add it to the crontab.

Currently used to make sure callbacks have been called for missed transactions.

# About this project

* Created and maintained by www.satoshiportal.com
* Dedicated full-time developer @kexkey
* Project manager @FrancisPouliot
* Contributor: @\_\_escapee\_\_
* Disclaimer: as of release on Sept. 23 2018 the project is still it its early stages (Alpha) and many of the features have yet to be implemented. The core architecture and basic wallet operations and blockchain query functions are fully functional.

# How to use cyphernode?

The core component of cyphernode is a request handler which exposes HTTP endpoints via REST API, acting as an absctration layer between your apps and the open-source Bitcoin sofware you want to interact with.

## Documentation

* Read the API docs here: 
  * API v0 (Current): https://github.com/SatoshiPortal/cyphernode/blob/master/doc/API.v0.md
  * API v1 (RESTful): https://github.com/SatoshiPortal/cyphernode/blob/master/doc/API.v1.md 
* Installation documentation: https://github.com/SatoshiPortal/cyphernode/blob/master/doc/INSTALL.md
* Step-by-step manual install (deprecated): https://github.com/SatoshiPortal/cyphernode/blob/master/doc/INSTALL-MANUAL-STEPS.md

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

## Security Roadmap

You can find it here: https://github.com/SatoshiPortal/cyphernode/issues/13#issue-364164006

# Example use-case for cyphernode

When building cyphernode, we had specific use-cases in mind that we built for ourselves. Use this as inspiration, and innovate on our procedures.

[See one of Satoshi Portal's use case flow](doc/SATOSHIPORTAL-WORKFLOW.md)

# Contributions

[See contributing document](CONTRIBUTING.md)
