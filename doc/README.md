# Cyphernode

Indirection layer (API) between your applications and Bitcoin-related services.

Your application <-----> Cyphernode

Cyphernode is:

Gatekeeper (TLS, JWT) <-----> Proxy (Cyphernode Core) <-----> Feature Containers

- By default, the only exposed (published) port is 443 (HTTPS) on the Gatekeeper.
- By default, everything else is accessible exclusively within the encrypted overlay network.
- If your system is distributed (customized Cyphernode setup), the overlay network...
  - ...should be doubly encrypted with a VPN or SSH tunnel
  - ...the hosts should be secured and the VPN/SSH tunnel should have limited scope by iptables rules on each host.
- We can have different Bitcoin Nodes for watching and spending, giving the flexibility to have different security models one each.
- Only the Proxy has Bitcoin Node RPC credentials.
- To manually manage the Proxy (and have access to it), one has to gain access to the Docker host servers as a docker user.

## Setting Up

### Installer

We are providing an installer to help you setup Cyphernode.

#### See [Instructions for installation](INSTALL.md) for automatic install instructions

All the Docker images used by Cyphernode have been prebuilt for x86, ARM (RPi) and aarch64 (pine64/NODL) architectures and are hosted on the Docker hub public registry, Cyphernode repository (https://hub.docker.com/u/cyphernode/).

### Build from sources

However, it is possible for you to build from sources.  In that case, please refer to the `build.sh` scripts in each of the repositories used by cyphernode (https://cloud.docker.com/u/cyphernode/repository/list).  See [Instructions for installation](INSTALL.md).

# For Your Information

Current components in Cyphernode:

- Gatekeeper: front door where all requests hit Cyphernode.  Takes care of: TLS, authentication and authorization.
- Proxy: request handler.  Well dispatch authenticated and authorized requests to the right component.  Use a SQLite3 database for its tasks.
- Proxy Cron: scheduler.  Can call the proxy on regular interval for asynchronous tasks like payment notifications on watches, callbacks when OTS files are ready, etc.
- Pycoin: Bitcoin keys and addresses tool.  Used by Cyphernode to derive addresses from an xPub and a derivation path.
- notifier: Handling callbacks used by watchers as well as OTS stamping.
- broker: pub/sub mechanism is taken care by the broker to which all subscribers and publishers should register.
- Bitcoin: Bitcoin Core node.  Cyphernode uses a watching wallet for watchers (no funds) and a spending wallet for spending.  Mandatory component, but optionally part of Cyphernode installation, as we can use an already running Bitcoin Core node.
- Lightning: optional.  C-Lightning node.  The LN node will use the Bitcoin node for its tasks.
- OTSclient: optional.  Used to stamp hashes on the Bitcoin blockchain.

Future components:

- Trezor-connect: use a Trezor to authenticate.  Will be used to log into control panel (see next point) and other.
- Control Panel: web control panel, with different functionalities depending on user's group: admin, spender, watcher.
- Grafana: displays stats graphics on Cyphernode use and load.
- PGP: signs anything with your PGP key.
- PSBT: sign transactions using a Coldcard.
- Electrum (Personal) Server: would be part of the installation for your convenience, but not really used by Cyphernode.

## Bitcoin Core Node

If you decide to have a prune Bitcoin Core node, the fee calculation on incoming transactions won't work.  We can't compute the fees on someone else's transactions without having the whole indexed blockchain.

## Lightning Network

Currently, basic LN functionalities is offered by Cyphernode.  You can:

- Get information on your LN node: ln_getinfo
- Get a Bitcoin address where to send your funds to be used by your LN node: ln_newaddr
- Create an invoice, so people can send you payment; the burden of creating a channel/route to you is on the payer: ln_create_invoice
- Pay an invoice.  You have to have the invoice and your LN node must already be connected to the network: ln_pay
- Decode a BOLT11 string.
- Delete a created invoice to make sure cancelled payments are not accepted.
- Get a previously created invoice.
- Connect + fund: connects to a peer and fund a channel, all in one call.  A callback can be provided to let you know when the channel is ready to use.
- Get connection string: to let your user know how to connect to your LN node.
- Be notified when a LN payment is received

## Manually test your installation through the Gatekeeper

If you need the authorization header to copy/paste in another tool, put your API ID (id=) and API key (k=) in the following command:

```shell
id="003";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+60))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";echo "Bearer $token"
```

Directly using curl on command line, put your API ID (id=) and API key (k=) in the following commands:

```shell
id="001";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" -k https://127.0.0.1/getbestblockhash
id="003";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" -k https://127.0.0.1/getbalance
id="003";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Content-Type: application/json" -d '{"hash":"123","callbackUrl":"http://callback"}' -H "Authorization: Bearer $token" -k https://127.0.0.1/ots_stamp
```


## Manually test your installation directly on the Proxy:

```shell
echo "GET /getbestblockinfo" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /getbalance" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /getbestblockhash" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /getblockinfo/00000000a64e0d1ae0c39166f4e8717a672daf3d61bf7bbb41b0f487fcae74d2" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /ln_getinfo" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
```
