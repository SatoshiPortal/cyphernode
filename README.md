Cyphernode is a Bitcoin microservices API server architecture, Bitcoin wallet management software and utilities toolkit to build scalable, secure and featureful apps and services without trusted third parties.

Combined with the Cypherapps framework, Cyphernode provides all advanced features and utilities necessary to build and deploy entreprise-grade applications such as Bitcoin exchanges, Bitcoin payment processors and Bitcoin wallets.

- Designed for Bitcoin builders: app devs, project managers, founders, R&D, prototypers, etc.
- Use your own full nodes exclusively: Bitcoin, Lightning and Liquid network
- Hold your own keys without compromise: hot wallets and cold store both supported
- Protect user privacy: 100% anonymous, no data leaks to 3rd parties

Cyphernode is has been used in production by www.bullbitcoin.com and www.bylls.com for every transaction in and out since June 2018.
Cyphernode was createad by created by @FrancisPouliot @Kexkey with financing and support by www.bullbitcoin.com and www.bylls.com.

# Bitcoin Wallet Management

Cyphernode allows its users to create and use Bitcoin Wallets via API, but it is not itself a Bitcoin wallet: it is Bitcoin wallet management tool that controls other Bitcoin Wallets. These wallets are used generally for two purposes: receiving Bitcoin payments and sending Bitcoin payments.

A fully-loaded cyphernode instance would have the following wallets:

- Bitcoin Core spender*: default hot wallet to send Bitcoin payments
- Bitcoin Core watcher*: monitoring addresses, transactions and blocks (notifications, balance tracking)
- Bitcoin Core PSBT: watch-only wallet for remote signing (e.g. ColdCard) 
- C-Lightning: receive and send Lightning Network payments
- Wasabi Wallet: mix bitcoins with coinjoin (also receive and send Bitcoin payments)
- Liquid (Elements): receive and send L-BTC and any Liquid assets

Generally speaking, **watcher** wallets are used for receiving payments and will not contain private keys and **spender** wallets are used for sending payments and will containt private keys (except for PSBT wallets).

In reality, there is only need for one **watcher** wallet in the cyphernode stack. It is simply a watch-only Bitcoin Core wallet (or Elemenets wallet) used to monitor Bitcoin addresses and transactions by detecting unconfirmed transactions and querying the Bitcoin blockchain. It is the functional equivalent of a "block explorer" or "balance tracker". A watcher wallet is accessible by users with "watcher" priviledges. 

## Receiving payment notifications and tracking wallet balances

Cyphernode was built originally as an alternative to Bitcoin block explorer APIs. It offers the same features as the most advances commercial APIs but with far greater reliability, flexbility, privacy and more advanced features.

Receiving Bitcoin payments involves the following crucial steps:

1. Generating a new Bitcoin addresses for each payment
2. Monitoring Bitcoin addresses for transactions (notifications)
3. Monitoring transactions for confirmations (notifications)
4. Updating payment requests after notifications
5. Logging and displaying transaction details

### Generating Bitcoin addresses

In Cyphernode, there are 6 ways to generate receiving addresses. The methods can be found in the proxy here below.

**Note: in the next sections, we cover what to do with Bitcoin adresses after you've generated them**

- [Wallet Operations](https://github.com/SatoshiPortal/cyphernode/blob/features/liquidwasabi/proxy_docker/app/script/walletoperations.sh)
- [Elements Wallet Operations](https://github.com/SatoshiPortal/cyphernode/blob/features/liquidwasabi/proxy_docker/app/script/elements_walletoperations.sh)
- [Bitcoin Derivation Utilities](https://github.com/SatoshiPortal/cyphernode/blob/features/liquidwasabi/proxy_docker/app/script/bitcoin.sh)
- [Manual or automated address import](https://github.com/SatoshiPortal/cyphernode/blob/features/liquidwasabi/proxy_docker/app/script/importaddress.sh)
- [Wasabi Wallet Operations](https://github.com/SatoshiPortal/cyphernode/blob/features/liquidwasabi/proxy_docker/app/script/wasabi.sh)
- [Lightning Wallet Operations](https://github.com/SatoshiPortal/cyphernode/blob/features/liquidwasabi/proxy_docker/app/script/call_lightningd.sh)

Note: always make sure you have access to the keys of the addresses you are generating, or if they are watch only, make sure you know where they are going.

1. [Dynamically derived from an XPUB (or ZPUB or YPUB)](https://github.com/SatoshiPortal/cyphernode/blob/79839fe94982324f59d485bf6266cc01ab43d3cf/doc/openapi/v0/cyphernode-api.yaml#L1253)
`action_deriveindex=spender
action_derivepubpath=spender`
Using this method, you can simply provide the zpub and it will automatically derive a new one each time. Or you can specify the path you want to derive. There is no limit to how many you can derive.
Note: here you would want to specify a segwit path
2. [From a Bitcoin Core spender using](https://github.com/SatoshiPortal/cyphernode/blob/79839fe94982324f59d485bf6266cc01ab43d3cf/doc/openapi/v0/cyphernode-api.yaml#L1044) `getnewaddress`
`action_getnewaddress=spender`
You can set the default Bitcoin address type in the Bitcoin Core configs or you can supply it each time you make an api call.
The default address type is native segwit (bech32).
3. [From Wasabi Wallet using](https://github.com/SatoshiPortal/cyphernode/blob/5080b796e6ddb4a00b1487b35a4cc3da9f4a1810/doc/openapi/v0/cyphernode-api.yaml#L1877) `wasabi_getnewaddress`
`action_wasabi_getnewaddress=spender`
These addresses will be native segwit (bech32) only.
4.[From C-Lightning using](https://github.com/SatoshiPortal/cyphernode/blob/79839fe94982324f59d485bf6266cc01ab43d3cf/doc/openapi/v0/cyphernode-api.yaml#L1405) `ln_create_invoice`
`action_ln_create_invoice=watcher`
5. [Getting an L-BTC address from Liquid (Elements)](https://github.com/SatoshiPortal/cyphernode/blob/56c3230bf2c99f0fbee3e71f66b364c811059ca1/proxy_docker/app/script/elements_walletoperations.sh#L6) spender
`action_elements_spend=spender`
`elements_getnweaddress`
By default these will be confidential addresses, legacy segwit (not belch32) because native segwit (blech32) is not compatible with Green by Blockstream.
6. [Manually import addresses, or use the importmulti function](https://github.com/SatoshiPortal/cyphernode/blob/features/liquidwasabi/proxy_docker/app/script/importaddress.sh)

### Watching Bitcoin addresses

The term "watching" in Cyphernode lingo means a function that will monitor Bitcoin address and send notifications either internally via the broker/notifier system or via api with webhook notifications at specified callback URLs.

There are two principal ways to watch Bitcoin addresses:
1. Watch each address individually: the addresses will be imported into the Bitcoin Core watcher wallet, notifications will be sent when they are involved in Bitcoin transactions. This is best if you are creating invoices, or watching deposit addresses for an account.
2. Watch XPUBs, YPUBs and ZPUBs: we will derive multiple addresses (batches of 1000) and import them all into Bitcoin Core, notifications will be sent when any of the adresses being watched are involved in Bitcoin transactions. In addition, this allows you to query the entire balance of the addresses in an XPUB. This would be for tracking all movements in and out of a wallet and logging these changes with balances, for example.

There is no real limit to how many addresses can be watched.

**Note: the difference between using addresses individually or watching an XPUB is you can specify different callback URLs for notifications and unique labels for individual watching, as well as event messages, which lets you know where the transactions are coming from and what is suppsed to happen next. When using the watch XPUB, you are monitoring for transactions and you will know which addresses are involved, but you will not be able to specific a different callback URL for each address.**

When watching a Bitcoin address, you can configure these additional options:
- Event Message: eventmesssage added to address Watches can be used as "triggers" for automate functions. An example of this is a Cypherapp feature developped by Bull Bitcoin called **The Bouncer** which will watch a Bitcoin address send the same received amount of Bitcoins or L-BTC to a Bitcoin address specified via the Event Message.
- Confirmations: you can chose when to be notified in number of confirmations (e.g. 0-conf, 1-conf, 6-conf, 100-conf, etc.)

**NOTE: XPUB labelling system (interal address tracker)**

Because we will be importanting many different addresses from many different xpubs into the same Bitcoin Core wallet (the watcher) we need a way to track which addresses belong to which XPUB, which Bitcoin Core watcher will not know.

The system we use by default is to put the XPUB itself as the label when importing addresses using the XPUB watcher feature. So we can tell which addresses were from which xpubs simply because the xpub is in the internal Bitcoin Core address label for all addresses. For this reason, we have some watching functions which are based on labels, and we can decide to watch addresses only of a certain label and send them collectively to one callback URLs (or grouping).

**Example code for a payment processor**

1. Getting a new address

```{
    "type": "cyphernode-address-created",
    "address": {
        "address": "tb1qhytxwr0q5q30kw49m4peek0j35s8nz4y55494d",
        "keyPath": "84'/0'/0'/0/22",
        "label": "[\"order 22\"]",
    }
}
```
```
{
    "type": "cyphernode-address-created",
    "address": {
        "address": "2MwhJkJWAuZevor6v1EPRPr4ZhWvZqhu7Sa"
    }
}
```
2. WebHook created for address `2MwhJkJWAuZevor6v1EPRPr4ZhWvZqhu7Sa`

```{
    "type": "cypnernode-hook-created",
    "field": "invoince_address",
    "address": "2MwhJkJWAuZevor6v1EPRPr4ZhWvZqhu7Sa",
    "is_error": false,
    "error": null,
    "result": {
        "id": "614",
        "event": "watch",
        "imported": "1",
        "inserted": "1",
        "address": "2MwhJkJWAuZevor6v1EPRPr4ZhWvZqhu7Sa",
        "unconfirmedCallbackURL": "`your_callback_url_1`"
        "confirmedCallbackURL": "`your_callback_url_2`",
        "estimatesmartfee2blocks": "0.00001000",
        "estimatesmartfee6blocks": "0.00001000",
        "estimatesmartfee36blocks": "0.00001000",
        "estimatesmartfee144blocks": "0.00001000",
        "eventMessage": "eyJib3VuY2VB13098fmoDdvosd230fggfxsg8BM0trblpQUlVKelNnWXkiLCJuYsdf23d9"
    }
}
```

3. Receive information for unconfirmed-tx event`
```{
    "_id": "YuJ5oLsRx73EzCKpt",
    "created_at": "2020-05-19T23:21:43.430Z",
    "opts": {
        "query": {
            "event": "unconfirmed-tx",
            "order_id": "asj109e2u1so"
        },
        "body": {
            "id": "615",
            "address": "tb1qhytxwr0q5q30kw49m4peek0j35s8nz4y55494d",
            "hash": "1287exvmb29hls02094igbsidif238j9b13a071eb69697f34b340ab76cec",
            "vout_n": 0,
            "sent_amount": 0.00161244,
            "confirmations": 0,
            "received": "2018-03-19T13:29:33+0000",
            "size": 518,
            "vsize": 276,
            "fees": 0.00000276,
            "is_replaceable": 0,
            "eventMessage": "eyJib3VuY2VB13098fmoDdvosd230fggfxsg8BM0trblpQUlVKelNnWXkiLCJuYsdf23d9"
        },
        "confirmations": 0
    }
}
```
```
{
    "_id": "YuJ5oLsRx73EzCKpt",
    "created_at": "2020-05-19T23:29:21.334Z",
    "opts": {
        "query": {
            "event": "confirmed-tx",
            "order_id": "asj109e2u1so",
        },
        "body": {
            "id": "615",
            "address": "tb1qhytxwr0q5q30kw49m4peek0j35s8nz4y55494d",
            "hash": "1287exvmb29hls02094igbsidif238j9b13a071eb69697f34b340ab76cec",
            "vout_n": 0,
            "vout_n": 0,
            "sent_amount": 0.00161244,
            "confirmations": 2,
            "received": "2018-03-19T13:32:13+0000",
            "size": 518,
            "vsize": 276,
            "fees": 0.00000276,
            "is_replaceable": 0,
            "blockhash": "0000000000000e5c7c34a643b4a43dfdcf907236ee615a32e00c565e482d4ba9",
            "blocktime": "2020-05-19T23:28:26+0000",
            "blockheight": 1745836,
            "eventMessage": "eyJib3VuY2VB13098fmoDdvosd230fggfxsg8BM0trblpQUlVKelNnWXkiLCJuYsdf23d9"
        },
        "confirmations": 2
}
```
## Watching transactions

The Watch Transaction feature will provide notitifications about a supplied txid, usually triggered by blocks. This is used internally in various processes, but it is also a neat feautre to watch transactions you are sending outbound to be notified with detailed information when the transaction confirms. You can also put a watch on inbound transactions to trigger specific event notifications.

A **spender** wallet 

The wallet API delegates the tasks of creating, signing and boradcasting transactions to various existing Bitcoin wallet software managed by the Cyphernode stack. 

- Bitcoin Core
- C-Lightning
- Wasabi Wallet
- Liquid network (Elements)

These wallets are hot wallets. In the Cyphernode framework, we call them "spender" wallets and only users with spending rights will be able to perform these actions. 

framework makes a disctinction between two main wallet functions:
- Spender
- Watcher

The job of spending wallets is unsprisingly to send outbound payments

## Send Bitcoin payments via wallet API

### Making Bitcoin transactions with Bitcoin Core
 
-> Call the spend endpoint to send Bitcoin payments
-> You can set confirmation target separately for each transaction 

`POST http://cyphernode:8888/spend
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"eventMessage":"eyJ3aGF0ZXZlciI6MTIzfQo=","confTarget":6,"replaceable":true,"subtractfeefromamount":false}`

-> Create and process PSBT files to sign remotely
-> "Bump fee" on RBF transactions
-> After sending a transaction, use the `watchtxid` endpoint with a callback URL to get webhook notifications for confirmations
-> Use `getbalances` and `getnewaddress` on the spender wallet to monitor refill the hot wallet

### Making Lightning Network transactions with C-Lightning

-> Make sure you have C-Lightning installed
-> blabla
-> blabla

### Wasabi Wallet 

-> We recommend using Bitcoin Core as primary hot wallet. Wasabi integration in Cyphernode is meant to be used primarily for Coinjoin.
-> You can call the wasabi_spend endpoint and specify which wallet instance you are using to send Bitcoin payments.

### PSBT offline signing

-> Create a new wallet using `create_wallet` endpoint
-> Load wallet using `load_wallet` endpoint
-> Make this wallet a PSBT wallet by calling the `psbt_enable` endpoint and adding the xpub of the wallet you want to use (e.g. from ColdCard)
-> This will import addresses into the newly craeted wallet, so you will probably want to enable the rescan option and specify a certain blockheight

### Liquid Wallet

-> You can send any Liquid asset using the `elements_spend` endpoint
-> You must always specify which asset you are sending by supplying the `assetId`. There is no default asset to avoid accidentally sending L-BTC to someone by accident because you did not specify the asset. The L-BTC assetId is `6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d`
-> Use the `elements_watchtxidrequest` request after receiving the transactionId from `elements_spend` to get noficiations about transaction confirmations

## Receive payments, track balances and get notifications

-> Watch a Bitcoin address and get notified to callback URL via Webhook

-> External wallet (xpub) tracker

## Receiving Bitcoin payments

Cyphernode allows you to create


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
