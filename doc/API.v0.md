# Cyphernode

## Current API

### Watch a Bitcoin Address (called by your application)

Inserts the address, webhook URLs and eventMessage in the DB and imports the address to the Watching wallet.  The webhook URLs (callbackURLs) and event message are optional.  If eventMessage is not supplied, the event will not be published to the tx_confirmation topic on confirmations.  Event message should be in base64 format to avoid dealing with escaping special characters.  The same address can be watched by different requests with different webhook URLs.

```http
POST http://cyphernode:8888/watch
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","eventMessage":"eyJib3VuY2VfYWRkcmVzcyI6IjJNdkEzeHIzOHIxNXRRZWhGblBKMVhBdXJDUFR2ZTZOamNGIiwibmJfY29uZiI6MH0K"}
```

Proxy response:

```json
{
  "id": "291",
    "event": "watch",
    "imported": "1",
    "inserted": "1",
    "address": "2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp",
    "unconfirmedCallbackURL": "192.168.133.233:1111/callback0conf",
    "confirmedCallbackURL": "192.168.133.233:1111/callback1conf",
    "estimatesmartfee2blocks": "0.000010",
    "estimatesmartfee6blocks": "0.000010",
    "estimatesmartfee36blocks": "0.000010",
    "estimatesmartfee144blocks": "0.000010",
    "eventMessage": "eyJib3VuY2VfYWRkcmVzcyI6IjJNdkEzeHIzOHIxNXRRZWhGblBKMVhBdXJDUFR2ZTZOamNGIiwibmJfY29uZiI6MH0K"
}
```

### Un-watch a previously watched Bitcoin Address (called by your application)

Updates the watched address row in DB so that webhooks won't be called on tx confirmations for that address.  You can POST the URLs to make sure you unwatch the good watcher, since there may be multiple watchers on the same address with different webhook URLs.  If you don't supply URLs and there are several watchers on the same address for different URLs, all watchers will be turned off for that address.  You can also, more conveniently, supply the watch id to unwatch.

```http
GET http://cyphernode:8888/unwatch/2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp
or
POST http://192.168.111.152:8080/unwatch
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
or
{"id":3124}
```

Proxy response:

```json
{
  "event": "unwatch",
  "address": "2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp",
  "unconfirmedCallbackURL": "192.168.133.233:1111/callback0conf",
  "confirmedCallbackURL": "192.168.133.233:1111/callback1conf"
}
```

### Get a list of Bitcoin addresses being watched (called by your application)

Returns the list of currently watched addresses and callback information.

```http
GET http://cyphernode:8888/getactivewatches
```

Proxy response:

```json
{
  "watches": [
    {
      "id":"291",
      "address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp",
      "imported":"1",
      "unconfirmedCallbackURL":"192.168.133.233:1111/callback0conf",
      "confirmedCallbackURL":"192.168.133.233:1111/callback1conf",
      "watching_since":"2018-09-06 21:14:03",
      "eventMessage":"eyJib3VuY2VfYWRkcmVzcyI6IjJNdkEzeHIzOHIxNXRRZWhGblBKMVhBdXJDUFR2ZTZOamNGIiwibmJfY29uZiI6MH0K"
    }
  ]
}
```

### Get a list of txns from a watched label

Returns the list of transactions not spend(txns) from watched label.

```http
GET http://cyphernode:8888/get_txns_by_watchlabel/Label
```

Proxy response:

```json
{
  "label_txns": [
    {
      "label": "Label",
      "address": "tb3qvsk9em20hgd76d489jyfdpy840vywk5qx9p5sg",
      "txid": "d48171ecc2ea4310ee7a15d9f11d8410d6a658225152b0c27122de1999d87cb2",
      "confirmations": "1",
      "blockheight": "1817509",
      "v_out": "0",
      "amount": "2.545e-05",
      "blockhash": "000000000000015df543042fa9179fe5e0823ef4e9a8cd52c9f26ce96b5935b1",
      "blocktime": "1596496264",
      "timereceived": "1596437271"
    }
  ]
}
```

### Get a list of unused address from a watched label

Returns the list all address not used from watched label.

```http
GET http://cyphernode:8888/get_unused_addresses_by_watchlabel/Label
```

Proxy response:

```json

{
  "label_unused_addresses": [
    {
      "pub32_watch_id": "8",
      "pub32_label": "Label",
      "pub32": "xpub5VFKvW1pNiCCZqM4eB2qNmJKJnUEzcsWOPDnnR37jMZzMBof1YCiw3MnVPgyTY8RFiBMSPX3rf3M1zGckKdsLoNv64FBd8E1vTS2PzqEgSz",
      "address_pub32_index": "0",
      "address": "tb1qvqdit92g96dkch5soru8p3c6whtn2w82n85fj6"
    }
  ]
}
```

### Watch a Bitcoin xpub/ypub/zpub/tpub/upub/vpub extended public key (called by your application)

Used to watch the transactions related to an xpub.  It will first derive 100 addresses using the provided xpub, derivation path and index information.  It will add those addresses to the watching DB table and add those addresses to the Watching-by-xpub wallet.  The watching process will take care of calling the provided callbacks when a transaction occurs.  When a transaction is seen, Cyphernode will derive and start watching new addresses related to the xpub, keeping a 100 address gap between the last used address in a transaction and the last watched address of that xpub.  The label can be used later, instead of the whole xpub, with unwatchxpub* and and getactivewatchesby*.

```http
POST http://cyphernode:8888/watchxpub
with body...
{"label":"4421","pub32":"upub57Wa4MvRPNyAhxr578mQUdPr6MHwpg3Su875hj8K75AeUVZLXtFeiP52BrhNqDg93gjALU1MMh5UPRiiQPrwiTiuBBBRHzeyBMgrbwkmmkq","path":"0/1/n","nstart":109,"unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
```

Proxy response:

```json
{
  "id":"5",
  "event":"watchxpub",
  "pub32":"upub57Wa4MvRPNyAhxr578mQUdPr6MHwpg3Su875hj8K75AeUVZLXtFeiP52BrhNqDg93gjALU1MMh5UPRiiQPrwiTiuBBBRHzeyBMgrbwkmmkq",
  "label":"2219",
  "path":"0/1/n",
  "nstart":"109",
  "unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf",
  "confirmedCallbackURL":"192.168.111.233:1111/callback1conf"
}
```

### Un-watch a previously watched Bitcoin xpub by providing the xpub (called by your application)

Updates the watched address rows in DB so that callbacks won't be called on tx confirmations for the provided xpub and related addresses.

```http
GET http://cyphernode:8888/unwatchxpubbyxpub/upub57Wa4MvRPNyAhxr578mQUdPr6MHwpg3Su875hj8K75AeUVZLXtFeiP52BrhNqDg93gjALU1MMh5UPRiiQPrwiTiuBBBRHzeyBMgrbwkmmkq
```

Proxy response:

```json
{
  "event":"unwatchxpubbyxpub",
  "pub32":"upub57Wa4MvRPNyAhxr578mQUdPr6MHwpg3Su875hj8K75AeUVZLXtFeiP52BrhNqDg93gjALU1MMh5UPRiiQPrwiTiuBBBRHzeyBMgrbwkmmkq"
}
```

### Un-watch a previously watched Bitcoin xpub by providing the label (called by your application)

Updates the watched address rows in DB so that callbacks won't be called on tx confirmations for the provided xpub and related addresses.

```http
GET http://cyphernode:8888/unwatchxpubbylabel/4421
```

Proxy response:

```json
{
  "event":"unwatchxpubbylabel",
  "label":"4421"
}
```

### Watch a TXID (called by your application)

Used to watch a transaction.  Will call the 1-conf callback url after the transaction has been mined.  Will call the x-conf callback url after the transaction has x confirmations.

```http
POST http://cyphernode:8888/watchtxid
with body...
{"txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387","confirmedCallbackURL":"192.168.111.233:1111/callback1conf","xconfCallbackURL":"192.168.111.233:1111/callbackXconf","nbxconf":6}
```

Proxy response:

```json
{
  "id":"5",
  "event":"watchtxid",
  "inserted":"1",
  "txid":"b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387",
  "confirmedCallbackURL":"192.168.111.233:1111/callback1conf",
  "xconfCallbackURL":"192.168.111.233:1111/callbackXconf",
  "nbxconf":6
}
```

### Get a list of Bitcoin xpub being watched (called by your application)

Returns the list of currently watched xpub and callback information.

```http
GET http://cyphernode:8888/getactivexpubwatches
```

Proxy response:

```json
{
  "watches": [
  {
  "id":"291",
  "pub32":"upub57Wa4MvRPNyAhxr578mQUdPr6MHwpg3Su875hj8K75AeUVZLXtFeiP52BrhNqDg93gjALU1MMh5UPRiiQPrwiTiuBBBRHzeyBMgrbwkmmkq",
  "label":"2217",
  "derivation_path":"1/3/n",
  "last_imported_n":"121",
  "unconfirmedCallbackURL":"192.168.133.233:1111/callback0conf",
  "confirmedCallbackURL":"192.168.133.233:1111/callback1conf",
  "watching_since":"2018-09-06 21:14:03"}
  ]
}
```

### Get a list of Bitcoin addresses being watched by provided xpub (called by your application)

Returns the list of currently watched addresses related to the provided xpub and callback information.

```http
GET http://cyphernode:8888/getactivewatchesbyxpub/tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk
```

Proxy response:

```json

{
  "watches": [
  {
    "id":"291",
    "address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp",
    "imported":"1",
    "unconfirmedCallbackURL":"192.168.133.233:1111/callback0conf",
    "confirmedCallbackURL":"192.168.133.233:1111/callback1conf",
    "watching_since":"2018-09-06 21:14:03",
    "derivation_path":"1/0/n",
    "pub32_index":"44"}
  ]
}
```

### Get a list of Bitcoin addresses being watched by provided xpub label (called by your application)

Returns the list of currently watched addresses related to the provided xpub label and callback information.

```http
GET http://cyphernode:8888/getactivewatchesbylabel/2219
```

Proxy response:

```json

{
  "watches": [
  {
    "id":"291",
    "address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp",
    "imported":"1",
    "unconfirmedCallbackURL":"192.168.133.233:1111/callback0conf",
    "confirmedCallbackURL":"192.168.133.233:1111/callback1conf",
    "watching_since":"2018-09-06 21:14:03",
    "derivation_path":"1/0/n",
    "pub32_index":"44"}
  ]
}
```

### Confirm a Transaction on Watched Address (called by Bitcoin node on transaction confirmations)

Confirms a transaction on an imported address.  The Watching Bitcoin node will notify Cyphernode (thanks to walletnotify in bitcoin.conf) by calling this endpoint with txid when a tx is new or updated on an address.  If address is still being watched (flag in DB), the corresponding callbacks will be called.

```http
GET http://cyphernode:8888/conf/b081ca7724386f549cf0c16f71db6affeb52ff7a0d9b606fb2e5c43faffd3387
```

Proxy response:

```json
{
  "result":"confirmed"
}
```

### Callbacks

When cyphernode receives a transaction confirmation (/conf endpoint) on a watched address, it makes an HTTP POST request using the corresponding callback URL previously supplied in the watch call (/watch endpoint).  The POST body will contain the following information:

```json
{
  "id":"3832",
  "address":"2NB96fbwy8eoHttuZTtbwvvhEYrBwz494ov",
  "hash":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
  "vout_n":1,
  "sent_amount":0.84050318,
  "confirmations":0,
  "received":"2018-10-18T15:41:06+0000",
  "size":371,
  "vsize":166,
  "fees":0.00002992,
  "replaceable":false,
  "blockhash":"",
  "blocktime":"",
  "blockheight":""
}
```

```json
{
  "id":"3832",
  "address":"2NB96fbwy8eoHttuZTtbwvvhEYrBwz494ov",
  "hash":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
  "vout_n":1,
  "sent_amount":0.84050318,
  "confirmations":1,
  "received":"2018-10-18T15:41:06+0000",
  "size":371,
  "vsize":166,
  "fees":0.00002992,
  "replaceable":false,
  "blockhash":"00000000000000000011bb83bb9bed0f6e131d0d0c903ec3a063e00b3aa00bf6",
  "blocktime":"2018-10-18T16:58:49+0000",
  "blockheight":""
}
```

### Get mempool information

Returns the mempool information of the Bitcoin node.
```http
GET http://cyphernode:8888/getmempoolinfo
```

Proxy response:

```json
{
  "size": 25,
  "bytes": 5462,
  "usage": 34736,
  "maxmempool": 64000000,
  "mempoolminfee": 1e-05,
  "minrelaytxfee": 1e-05
}
```

### Get the blockchain information (called by your application)

Returns the blockchain information of the Bitcoin node.  Used for example by the welcome app to get syncing progression.

```http
GET http://cyphernode:8888/getblockchaininfo
```

Proxy response:

```json
{
  "chain": "test",
  "blocks": 1486864,
  "headers": 1486864,
  "bestblockhash": "000000000000002fb99d683e64bbfc2b7ad16f9a425cf7be77b481fb1afa363b",
  "difficulty": 13971064.71015782,
  "mediantime": 1554149114,
  "verificationprogress": 0.9999994536561675,
  "initialblockdownload": false,
  "chainwork": "000000000000000000000000000000000000000000000103ceb57a5896f347ce",
  "size_on_disk": 23647567017,
  "pruned": false,
  "softforks": [
    {
      "id": "bip34",
      "version": 2,
      "reject": {
        "status": true
      }
    },
    {
      "id": "bip66",
      "version": 3,
      "reject": {
        "status": true
      }
    },
    {
      "id": "bip65",
      "version": 4,
      "reject": {
        "status": true
      }
    }
  ],
  "bip9_softforks": {
    "csv": {
      "status": "active",
      "startTime": 1456790400,
      "timeout": 1493596800,
      "since": 770112
    },
    "segwit": {
      "status": "active",
      "startTime": 1462060800,
      "timeout": 1493596800,
      "since": 834624
    }
  },
  "warnings": "Warning: unknown new rules activated (versionbit 28)"
}
```

### Get the Block Hash from Height (called by your application)

Returns the best block hash matching height provided.

```http
GET http://cyphernode:8888/getblockhash/593104
```

Proxy response:

```json
{
  "result":"00000000000000000005dc459f0575b17413dbe7685e3e0fd382ed521f1be68b",
  "error":null,
  "id":null
}
```

### Get the Best Block Hash (called by your application)

Returns the best block hash of the watching Bitcoin node.

```http
GET http://cyphernode:8888/getbestblockhash
```

Proxy response:

```json
{
  "result":"00000000000000262588c21afbf9e1da151daf10b11215d501271163f26ea74a",
  "error":null,
  "id":null
}
```

### Get Block Info (called by your application)

Returns block info for the supplied block hash.

```http
GET http://cyphernode:8888/getblockinfo/000000006f82a384c208ecfa04d05beea02d420f3f398ddda5c7f900de5718ea
```

Proxy response:

```json
{
  "result":
  {
  "hash":"000000006f82a384c208ecfa04d05beea02d420f3f398ddda5c7f900de5718ea",
  "confirmations":124329,
  "strippedsize":8067,
  "size":8067,
  "weight":32268,
  "height":1288528,
  "version":536870912,
  "versionHex":"20000000",
  "merkleroot":"f1596255c357713c9827a739b17c8445cdcb81c4d336e24516c66f714a8f7030",
  "tx":["65759382e7047f89f7e80676026c10401d47ce47ea997138251c59ca58f28a03","4d2d0cdd89061ce4bb8bdf5502aec9799e5065d205e8ab75c6598bd90a0e6e4c",[...],"a6d2fda52467aa7ca1271529ded5510bd12ad58f99f73fe995f50691aea4eb06"],
  "time":1521404668,
  "mediantime":1521398617,
  "nonce":4209349744,
  "bits":"1d00ffff",
  "difficulty":1,
  "chainwork":"000000000000000000000000000000000000000000000037e37554821063611f",
  "nTx":32,
  "previousblockhash":"000000005b55cefec377f7f73e656fef835a928b6eeb2060a89e7eb23a573c49",
  "nextblockhash":"000000000ab13797b6dddd5e28d2ed62b937cd65ecf49b1f9d75108b9ea500f9"
  },
  "error":null,
  "id":null
}
```

### Get the Best Block Info (called by your application)

Returns best block info: calls getblockinfo with bestblockhash.

```http
GET http://cyphernode:8888/getbestblockinfo
```

Proxy response:

```json
{
  "result":
  {
  "hash":"000000006f82a384c208ecfa04d05beea02d420f3f398ddda5c7f900de5718ea",
  "confirmations":124329,
  "strippedsize":8067,
  "size":8067,
  "weight":32268,
  "height":1288528,
  "version":536870912,
  "versionHex":"20000000",
  "merkleroot":"f1596255c357713c9827a739b17c8445cdcb81c4d336e24516c66f714a8f7030",
  "tx":["65759382e7047f89f7e80676026c10401d47ce47ea997138251c59ca58f28a03","4d2d0cdd89061ce4bb8bdf5502aec9799e5065d205e8ab75c6598bd90a0e6e4c",[...],"a6d2fda52467aa7ca1271529ded5510bd12ad58f99f73fe995f50691aea4eb06"],
  "time":1521404668,
  "mediantime":1521398617,
  "nonce":4209349744,
  "bits":"1d00ffff",
  "difficulty":1,
  "chainwork":"000000000000000000000000000000000000000000000037e37554821063611f",
  "nTx":32,
  "previousblockhash":"000000005b55cefec377f7f73e656fef835a928b6eeb2060a89e7eb23a573c49",
  "nextblockhash":"000000000ab13797b6dddd5e28d2ed62b937cd65ecf49b1f9d75108b9ea500f9"
  },
  "error":null,
  "id":null
}
```

### Get a transaction details (node's getrawtransaction) (called by your application)

Calls getrawtransaction RPC for the supplied txid.

```http
GET http://cyphernode:8888/gettransaction/af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648
```

Proxy response:

```json
{
  "result":
  {
  "txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
  "hash":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
  "version":1,
  "size":223,
  "vsize":223,
  "locktime":0,
  "vin":[
  {
  "txid":"53a0e2ffa456b97d3944b652bba771221e60f4d852546bd6b351d33261b3e8b6",
  "vout":0,
  "scriptSig":
  {
  "asm":"30440220127c4adc1cf985cd884c383e69440ce4d48a0c4fdce6bf9d70faa0ee8092acb80220632cb6c99ded7f261814e602fc8fa8e7fe8cb6a95d45c497846b8624f7d19b3c[ALL] 03df001c8b58ac42b6cbfc2223b8efaa7e9a1911e529bd2c8b7f90140079034e75",
  "hex":"4730440220127c4adc1cf985cd884c383e69440ce4d48a0c4fdce6bf9d70faa0ee8092acb80220632cb6c99ded7f261814e602fc8fa8e7fe8cb6a95d45c497846b8624f7d19b3c012103df001c8b58ac42b6cbfc2223b8efaa7e9a1911e529bd2c8b7f90140079034e75"
  },
  "sequence":4294967295
  }
  ],
  "vout":[
  {
  "value":0.84000000,
  "n":0,
  "scriptPubKey":
  {
  "asm":"OP_HASH160 c449a7fafb3b13b2952e064f2c3c58e851bb9430 OP_EQUAL",
  "hex":"a914c449a7fafb3b13b2952e064f2c3c58e851bb943087",
  "reqSigs":1,
  "type":"scripthash",
  "addresses":[
  "2NB96fbwy8eoHttuZTtbwvvhEYrBwz494ov"
  ]
  }
  },
  {
  "value":0.01890000,
  "n":1,
  "scriptPubKey":
  {
  "asm":"OP_DUP OP_HASH160 b0379374df5eab8be9a21ee96711712bdb781a95 OP_EQUALVERIFY OP_CHECKSIG",
  "hex":"76a914b0379374df5eab8be9a21ee96711712bdb781a9588ac",
  "reqSigs":1,
  "type":"pubkeyhash",
  "addresses":[
  "mwahoJcaVuy2TiMtGDZV9PaujFeD9z1a1q"
  ]
  }
  }
  ],
  "hex":"0100000001b6e8b36132d351b3d66b5452d8f4601e2271a7bb52b644397db9[...]4df5eab8be9a21ee96711712bdb781a9588ac00000000",
  "blockhash":"000000009249e7d725cc087cb781ade1dbfaf2bd777822948d5fccd4044f8299",
  "confirmations":1106162,
  "time":1415240575,
  "blocktime":1415240575
  },
  "error":null,
  "id":null
}
```

### Try missed callbacks (called by proxycronnode, a CRON job that retries if something went wrong)
[See cron_docker](../cron_docker)

Looks in DB for watched addresses, ask the watching Bitcoin node if those addresses got payments, if so it executes the callbacks that would be usually executed when "conf" is called by the node.  This is useful if the watching node went down or there was a network glitch when a transaction on a watched address got confirmed.

```http
GET http://cyphernode:8888/executecallbacks
```

Proxy response: EMPTY

### Get txns from spending wallet

Calls listtransactions bitcoin RPC on the spending wallet.

```http
GET http://cyphernode:8888/get_txns_spending
```

Proxy response:

```json
{
  "txns": [
    {
      "address": "tb1qfk6r46fj0u0we3c9lt0arl0dhqg2cry2sch7mf",
      "category": "receive",
      "amount": 0.00160052,
      "label": "",
      "vout": 0,
      "confirmations": 21125,
      "blockhash": "000000008c232ec9447e0cbcefdbd128a707c98189d4ab5036fdce3c313f0621",
      "blockindex": 73,
      "blocktime": 1595094603,
      "txid": "dc598f96f50f6b1ab36b3172315e0fd928279dd0d909708b60af124c022e1e68",
      "walletconflicts": [],
      "time": 1595096613,
      "timereceived": 1595216058,
      "bip125-replaceable": "no"
    }
  ]
}
```

### Get spending wallet's balance (called by your application)

Calls getbalance RPC on the spending wallet.

```http
GET http://cyphernode:8888/getbalance
```

Proxy response:

```json
{
  "balance":1.51911837
}
```

### Get spending wallet's extended balances (called by your application)

Calls getbalances RPC on the spending wallet.

```http
GET http://cyphernode:8888/getbalances
```

Proxy response:

```json
{
  "balances": {
    "mine": {
      "trusted": 1.29979716,
      "untrusted_pending": 0,
      "immature": 0
    }
  }
}
```

### Get a new Bitcoin address from spending wallet (called by your application)

Calls getnewaddress RPC on the spending wallet.  Used to refill the spending wallet from cold wallet (ie Trezor).  Will derive the default address type (set in your bitcoin.conf file, p2sh-segwit if not specified) or you can supply the address type like the following examples.

```http
GET http://cyphernode:8888/getnewaddress
GET http://cyphernode:8888/getnewaddress/bech32
GET http://cyphernode:8888/getnewaddress/legacy
GET http://cyphernode:8888/getnewaddress/p2sh-segwit
```

Proxy response:

```json
{
  "address":"2NEC972DZpRM7SfuJUG9rYEix2P9A8qsNKF"
}
```

```json
{
  "address":"tb1ql7yvh3lmajxmaljsnsu3w8lhwczu963tvjfzpj"
}
```

### Spend coins from spending wallet (called by your application)

Calls sendtoaddress RPC on the spending wallet with supplied info.  Can supply an eventMessage to be published on successful spending.  eventMessage should be base64 encoded to avoid dealing with escaping special characters.

```http
POST http://cyphernode:8888/spend
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
or
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"eventMessage":"eyJ3aGF0ZXZlciI6MTIzfQo=","confTarget":6,"replaceable":true,"subtractfeefromamount":false}
```

Proxy response:

```json
{
  "status": "accepted",
  "hash": "af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
  "details":
  {
    "address": "2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp",
    "amount": 0.00233,
    "firstseen": 1584568841,
    "size": 222,
    "vsize": 141,
    "replaceable": true,
    "fee": 0.00000141,
    "subtractfeefromamount": false
  }
}
```

### Bump transaction's fees (called by your application)

Calls bumpfee RPC on the spending wallet with supplied info.

```http
POST http://cyphernode:8888/bumpfee
with body...
{"txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648","confTarget":4}
or...
{"txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648"}
```

Proxy response:

```json
{
  "txid": "7c048f43af90315e201ff4dada8796605a2505c7ab54054ba0e9e05cadd9079b",
  "origfee": 0.00041221,
  "fee": 0.00068112,
  "errors": [ "Blabla don't do that" ]
}
```

### Add an output to the next batched transaction (called by your application)

Inserts output information in the DB.  Used when batchspend is called later.

```http
POST http://cyphernode:8888/addtobatch
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
```

Proxy response: EMPTY

### Spend a batched transaction with outputs added with addtobatch (called by your application)

Calls sendmany RPC on spending wallet with the unspent "addtobatch" inserted outputs.  Will be useful during next bull run.

```http
GET http://cyphernode:8888/batchspend
```

Proxy response:

```json
{
  "status": "accepted",
  "hash": "af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648"
}
```

### Get derived address(es) using path in config and provided index (called by your application)

Derives addresses for supplied index.  Must be used with derivation.pub32 and derivation.path properties in config.properties.

```http
GET http://cyphernode:8888/deriveindex/25-30
GET http://cyphernode:8888/deriveindex/34
```

Proxy response:

```json
{
  "addresses":[
  {"address":"2N6Q9kBcLtNswgMSLSQ5oduhbctk7hxEJW8"},
  {"address":"2NFLhFghAPKEPuZCKoeXYYxuaBxhKXbmhBV"},
  {"address":"2N7gepbQtRM5Hm4PTjvGadj9wAwEwnAsKiP"},
  {"address":"2Mth8XDZpXkY9d95tort8HYEAuEesow2tF6"},
  {"address":"2MwqEmAXhUw6H7bJwMhD13HGWVEj2HgFiNH"},
  {"address":"2N2Y4BVRdrRFhweub2ehHXveGZC3nryMEJw"}
  ]
}
```

### Get derived address(es) using provided path and index (called by your application)

Derives addresses for supplied pub32 and path.  config.properties' derivation.pub32 and derivation.path are not used.

```http
POST http://cyphernode:8888/derivepubpath
with body...
{"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}

or

{"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/34"}

or

{"pub32":"vpub5SLqN2bLY4WeZF3kL4VqiWF1itbf3A6oRrq9aPf16AZMVWYCuN9TxpAZwCzVgW94TNzZPNc9XAHD4As6pdnExBtCDGYRmNJrcJ4eV9hNqcv","path":"0/25-30"}
```

Proxy response:

```json
{
  "addresses":[
  {"address":"mz3bWMW3BWGT9YGDjJwS8TfhJMMtZ91Frm"},
  {"address":"mkjmKEX3KJrVpiqLSSxKB6jjgm3WhPnrv8"},
  {"address":"mk43Tmf6E5nsmETTaNMTZK9TikaeVJRJ4a"},
  {"address":"n1SEcVHHKpHyNr695JpXNdH6b9cWQ26qkt"},
  {"address":"mzWqwZkA31kYVy1kpMoZgvfzSDyGgEi7Yg"},
  {"address":"mp5jtEDNa88xfSQGs5yYQGk7guGWvaG4ci"}
  ]
}
```

### Get info from Lightning Network node (called by your application)

Calls getinfo from lightningd.  Useful to let your users know where to connect to.

```http
GET http://cyphernode:8888/ln_getinfo
```

Proxy response:

```json
{
  "id": "03lightningnode",
  "alias": "SatoshiPortal08",
  "color": "008000",
  "address": [
  ],
  "binding": [
    {
      "type": "ipv6",
      "address": "::",
      "port": 9735
    },
    {
      "type": "ipv4",
      "address": "0.0.0.0",
      "port": 9735
    }
  ],
  "version": "v0.6.1rc1-40-gae61f64",
  "blockheight": 1412861,
  "network": "testnet"
}
```

### Create a Lightning Network invoice (called by your application)

Returns a LN invoice.  Label must be unique.  Description will be used by your user for payment.  Expiry is in seconds and optional.  If msatoshi is not supplied, will use "any" (ie donation invoice).  callbackUrl is optional.

```http
POST http://cyphernode:8888/ln_create_invoice
with body...
{"msatoshi":10000,"label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":900,"callbackUrl":"https://thesite/lnwebhook/9d8sa98yd"}
or
{"label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":900}
```

Proxy response:

```json
{
  "payment_hash": "fd27edf261d4b089c3478dece4f2c92c8c68db7be3999e89d452d39c083ad00f",
  "expires_at": 1536593926,
  "bolt11": "lntb100n1pdedryzpp5l5n7munp6jcgns683hkwfukf9jxx3kmmuwveazw52tfeczp66q8sdqagfukcmrnyphhyer9wgszxvfsxc6rjxqzuycqp2ak5feh7x7wkkt76uc5ptzcv90jhzhs5swzefv9344hnv74c25dvsstx7l24y46sx5tnkenu480pe06wtly2h5lrj63vszzgrxt4grkcqcltquj"
}
```

### Pay a Lightning Network invoice (called by your application)

Make a LN payment.  expected_msatoshi and expected_description are respectively the amount and description you gave your user for her to create the invoice; they must match the given bolt11 invoice supplied by your user.  If the bolt11 invoice doesn't contain an amount, then the expected_msatoshi supplied here will be used as the paid amount.

```http
POST http://cyphernode:8888/ln_pay
with body...
{"bolt11":"lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3","expected_msatoshi":10000,"expected_description":"Bitcoin Outlet order #7082"}
```

Proxy response:

```json
{
  "id": 9,
  "payment_hash": "85b8e69733202e126620e7745be9e23a6b544b758145d86848f3e513e6e1ca42",
  "destination": "03whatever",
  "msatoshi": 50000000,
  "msatoshi_sent": 10000,
  "created_at": 1537025047,
  "status": "complete",
  "payment_preimage": "fececdc787a007a721a1945b70cb022149cc2ee4268964c99ba37a877bded664",
  "description": "Bitcoin Outlet order #7082",
  "getroute_tries": 1,
  "sendpay_tries": 1,
  "route": [
    {
      "id": "03whatever",
      "channel": "1413467:78:0",
      "msatoshi": 10000,
      "delay": 10
    }
  ],
  "failures": [
  ]
}

```

### Get a new Bitcoin address from the Lightning Network node (to fund it) (called by your application)

Returns a Bitcoin bech32 address to fund your LN wallet.

```http
GET http://cyphernode:8888/ln_newaddr
```

Proxy response:

```json
{
  "address": "tb1q9n8jfwe9qvlgczfxa5n4pe7haarqflzerqfhk9"
}
```

### Get your Lightning Network Node connection string, for others to connect to you

Returns a string containing your LN node connection information.

```http
GET http://cyphernode:8888/ln_getconnectionstring
```

Proxy response:

```json
{
  "connectstring": "02ffb6242a744143d427cf0962fce182d426609b80034a297ea5879c8c64d326ab@24.25.26.27:9735"
}
```

### Connect to a LN node and fund a channel with it

First, it will connect your LN node to the supplied LN node.  Then, it will fund a channel of the provided amount between you two.  Cyphernode will call the supplied callback URL when the channel is ready to be used.

```http
POST http://cyphernode:8888/ln_connectfund
with body...
{"peer":"nodeId@ip:port","msatoshi":"100000","callbackUrl":"https://callbackUrl/?channelReady=f3y2c3cvm4uzg2gq"}
```

Proxy response:

```json
{
  "result": "success",
  "txid": "85b8e69733202e126620e7745be9e23a6b544b758145d86848f3e513e6e1ca42",
  "channel_id": "a459352219deb8e1b6bdc4a3515888569adad8a3023f8b57edeb0bc4d1f77b74"
}
```

```json
{
  "result": "failed",
  "message": "Failed at watching txid"
}
```

### Get a previously created Lightning Network invoice by its label

Returns the invoice corresponding to the supplied label.

```http
GET http://cyphernode:8888/ln_getinvoice/label
GET http://cyphernode:8888/ln_getinvoice/koNCcrSvhX3dmyFhW
```

Proxy response:

```json
{
  "invoices": [
    {
      "label": "koNCcrSvhX3dmyFhW",
      "bolt11": "lntb10n1pw92fk9pp56p6g7nnuhcj63j6wpyquy67wc7xfanhc20d49ta2dzrge2mj3s5qdq9vscnzcqp2rzjqvdcvlvavcc6zdfvcrehhn4ff024s75dfaqyzmzvuxsj2yd3u684v93ylqqqq0sqqqqqqqqpqqqqqzsqqcu6jamf7du64nxtj99x5t6hvy4hlfv8fc8m5j39g8kyzpk5r89s28f93x5jsfnzl8mhtkhqvx2qxehns4ltw7w5h8h7ppdcw8t0uz0wcptztsqg",
      "payment_hash": "d0748f4e7cbe25a8cb4e0901c26bcec78c9ecef853db52afaa68868cab728c28",
      "msatoshi": 1000,
      "status": "paid",
      "pay_index": 10,
      "msatoshi_received": 1002,
      "paid_at": 1549084373,
      "description": "d11",
      "expires_at": 1549087957
    }
  ]
}
```

### Delete a previously created Lightning Network invoice by its label

Deletes the invoice corresponding to the supplied label if status is unpaid, so that no payment comes in.  Returns the invoice corresponding to the supplied label.

```http
GET http://cyphernode:8888/ln_delinvoice/label
GET http://cyphernode:8888/ln_delinvoice/koNCcrSvhX3dmyFhW
```

Proxy response:

```json
{
  "label": "koNCcrSvhX3dmyFhW",
  "bolt11": "lntb10n1pw92fk9pp56p6g7nnuhcj63j6wpyquy67wc7xfanhc20d49ta2dzrge2mj3s5qdq9vscnzcqp2rzjqvdcvlvavcc6zdfvcrehhn4ff024s75dfaqyzmzvuxsj2yd3u684v93ylqqqq0sqqqqqqqqpqqqqqzsqqcu6jamf7du64nxtj99x5t6hvy4hlfv8fc8m5j39g8kyzpk5r89s28f93x5jsfnzl8mhtkhqvx2qxehns4ltw7w5h8h7ppdcw8t0uz0wcptztsqg",
  "payment_hash": "d0748f4e7cbe25a8cb4e0901c26bcec78c9ecef853db52afaa68868cab728c28",
  "msatoshi": 1000,
  "status": "unpaid",
  "description": "d11",
  "expires_at": 1549087957
}
```

### Decodes the BOLT11 string of a Lightning Network invoice

Returns the detailed information of a BOLT11 string of a Lightning Network invoice.

```http
GET http://cyphernode:8888/ln_decodebolt11/bolt11
GET http://cyphernode:8888/ln_decodebolt11/lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3
```

Proxy response:

```json
{
  "currency": "tb",
  "created_at": 1536073035,
  "expiry": 3600,
  "payee": "03bb990f43e6a6eccb223288d32fcb91209b12370c0a8bf5cdf4ad7bc11e33f253",
  "description": "Bitcoin Outlet order #7082",
  "min_final_cltv_expiry": 10,
  "payment_hash": "430fb9d240fcb4612c335d475f285820dc9891588e19baf048520189c8af49e2",
  "signature": "30440220445a7d39cd4b086c0bd6c67cd8cd5a6a86e8b9345883b56e89fa851decfb876202206b1e6c5122a46c5fbba4ccb4a77ef1bb20078f0aeea4059d5ca3f773db85c920"
}
```

### Get the list of peers, with channels, from Lightning Network node (called by your application)

Calls listpeers from lightningd.  Returns the list of peers and the channels opened with them, even for currently offline peers.

```http
GET http://cyphernode:8888/ln_listpeers
```

Proxy response:

```json
{
   "peers": [
      {
         "id": "0[REDACTED]e",
         "connected": true,
         "netaddr": [
            "181.[REDACTED].228:9735"
         ],
         "globalfeatures": "",
         "localfeatures": "81",
         "features": "81",
         "channels": [
            {
               "state": "CHANNELD_NORMAL",
               "scratch_txid": "3[REDACTED]e",
               "owner": "channeld",
               "short_channel_id": "6[REDACTED]6x0",
               "direction": 0,
               "channel_id": "7[REDACTED]c",
               "funding_txid": "0[REDACTED]f",
               "close_to_addr": "bc1[REDACTED]f",
               "close_to": "0[REDACTED]6",
               "private": false,
               "funding_allocation_msat": {
                  "0[REDACTED]e": 0,
                  "0[REDACTED]a": 699139000
               },
               "funding_msat": {
                  "0[REDACTED]e": "0msat",
                  "0[REDACTED]a": "699139000msat"
               },
               "msatoshi_to_us": 699128000,
               "to_us_msat": "699128000msat",
               "msatoshi_to_us_min": 699128000,
               "min_to_us_msat": "699128000msat",
               "msatoshi_to_us_max": 699139000,
               "max_to_us_msat": "699139000msat",
               "msatoshi_total": 699139000,
               "total_msat": "699139000msat",
               "dust_limit_satoshis": 546,
               "dust_limit_msat": "546000msat",
               "max_htlc_value_in_flight_msat": 12446749275109551625,
               "max_total_htlc_in_msat": "12446749275109551625msat",
               "their_channel_reserve_satoshis": 6998,
               "their_reserve_msat": "6998000msat",
               "our_channel_reserve_satoshis": 6997,
               "our_reserve_msat": "6997000msat",
               "spendable_msatoshi": 688236000,
               "spendable_msat": "688236000msat",
               "htlc_minimum_msat": 0,
               "minimum_htlc_in_msat": "0msat",
               "their_to_self_delay": 144,
               "our_to_self_delay": 144,
               "max_accepted_htlcs": 483,
               "status": [
                  "CHANNELD_NORMAL:Reconnected, and reestablished.",
                  "CHANNELD_NORMAL:Funding transaction locked. Channel announced."
               ],
               "in_payments_offered": 0,
               "in_msatoshi_offered": 0,
               "in_offered_msat": "0msat",
               "in_payments_fulfilled": 0,
               "in_msatoshi_fulfilled": 0,
               "in_fulfilled_msat": "0msat",
               "out_payments_offered": 2,
               "out_msatoshi_offered": 13245566,
               "out_offered_msat": "13245566msat",
               "out_payments_fulfilled": 1,
               "out_msatoshi_fulfilled": 11000,
               "out_fulfilled_msat": "11000msat",
               "htlcs": []
            }
         ]
      },
      {
         "id": "0[REDACTED]9",
         "connected": true,
         "netaddr": [
            "wp[REDACTED]d.onion:9735"
         ],
         "globalfeatures": "",
         "localfeatures": "2281",
         "features": "2281",
         "channels": [
            {
               "state": "CHANNELD_NORMAL",
               "scratch_txid": "8[REDACTED]f",
               "owner": "channeld",
               "short_channel_id": "6[REDACTED]3x0",
               "direction": 1,
               "channel_id": "9[REDACTED]3",
               "funding_txid": "2[REDACTED]e",
               "close_to_addr": "bc1[REDACTED]d",
               "close_to": "0[REDACTED]f",
               "private": false,
               "funding_allocation_msat": {
                  "0[REDACTED]9": 0,
                  "0[REDACTED]a": 328682000
               },
               "funding_msat": {
                  "0[REDACTED]9": "0msat",
                  "0[REDACTED]a": "328682000msat"
               },
               "msatoshi_to_us": 328682000,
               "to_us_msat": "328682000msat",
               "msatoshi_to_us_min": 328682000,
               "min_to_us_msat": "328682000msat",
               "msatoshi_to_us_max": 328682000,
               "max_to_us_msat": "328682000msat",
               "msatoshi_total": 328682000,
               "total_msat": "328682000msat",
               "dust_limit_satoshis": 546,
               "dust_limit_msat": "546000msat",
               "max_htlc_value_in_flight_msat": 12446744073709551615,
               "max_total_htlc_in_msat": "12446744073709551615msat",
               "their_channel_reserve_satoshis": 7287,
               "their_reserve_msat": "7287000msat",
               "our_channel_reserve_satoshis": 7286,
               "our_reserve_msat": "7286000msat",
               "spendable_msatoshi": 727826000,
               "spendable_msat": "727826000msat",
               "htlc_minimum_msat": 0,
               "minimum_htlc_in_msat": "0msat",
               "their_to_self_delay": 144,
               "our_to_self_delay": 144,
               "max_accepted_htlcs": 483,
               "status": [
                  "CHANNELD_NORMAL:Sent reestablish, waiting for theirs"
               ],
               "in_payments_offered": 0,
               "in_msatoshi_offered": 0,
               "in_offered_msat": "0msat",
               "in_payments_fulfilled": 0,
               "in_msatoshi_fulfilled": 0,
               "in_fulfilled_msat": "0msat",
               "out_payments_offered": 20,
               "out_msatoshi_offered": 3104386818,
               "out_offered_msat": "3104386818msat",
               "out_payments_fulfilled": 0,
               "out_msatoshi_fulfilled": 0,
               "out_fulfilled_msat": "0msat",
               "htlcs": []
            }
         ]
      }
   ]
}
```

### Get list of funds in unused outputs and channels from c-lightning
Calls listfunds from lightningd. Returns the list of unused outputs and funds in open channels

```http
GET http://cyphernode:8888/ln_listfunds
```

Proxy response:

```json
{
   "outputs": [                                                                                             
    {                                               
      "txid": "d3a536efaa70671xxxxxxxxx8f349a3c326b79",
      "output": 0,                                                                                         
      "value": 9551,
      "amount_msat": "9551000msat",
      "address": "tb1qq0....j9kqze0",
      "status": "confirmed",
      "blockheight": 1715749
    },
    {}                                               
  ],
  "channels": [
  {
      "peer_id": "03f60f736....34f05a93a8a897b75c7940a55bb9",
      "connected": true,
      "state": "CHANNELD_NORMAL",
      "short_channel_id": "166...x0",
      "channel_sat": 100000,
      "our_amount_msat": "100000000msat",
      "channel_total_sat": 100000,
      "amount_msat": "100000000msat",
      "funding_txid": "53cf8cd...0c41c2e2b17887b3",
      "funding_output": 0
    },
    {}
  ]          
}
```

### Get the list of payments made by our node
Calls listpays from lightningd.
Returns history of paid invoices

```http
GET http://cyphernode:8888/ln_listpays
```

Proxy response:

```json
{
  "pays":
  [
   {
    "bolt11": "lntb10n1p0xjw9q....rlkv26swnt85pkwumkfmgaal8sa2awj2adajuzy82e0v6x8cqpzr2t8a",
    "status": "complete",
    "preimage": "1127e1fdb....54cc180e3d7",
    "amount_sent_msat": "1000msat"
   },
   {}
  ]
}
```

### Get an array of nodes that represent a possible route from our node to a given node for a given msatoshi payment amount

Calls getroute from lightningd. Returns an array representing hops of nodes to get to the destination node from our node

```http
GET http://cyphernode:8888/ln_getroute/<node_id>/<msatoshi>/<?riskfactor>
GET http://cyphernode:8888/ln_getroute/0308dbd05278e5802dd36436a41b226824283526eb14a08d334cbbc878243b243c/10000
GET http://cyphernode:8888/ln_getroute/0308dbd05278e5802dd36436a41b226824283526eb14a08d334cbbc878243b243c@ln.sifir.io/10000/.2
```
Proxy response:

```json
{ 
"route": [
  {
    "id": "03d5e17a3c2....a7c003",
    "channel": "166....0",
    "direction": 0,
    "msatoshi": 21000,
    "amount_msat": "21000msat",
    "delay": 64,
    "style": "tlv"
  },
  {
    "id": "038863cf8ab910....3b9",
    "channel": "1666....x1",
    "direction": 1,
    "msatoshi": 21000,
    "amount_msat": "21000msat",
    "delay": 49,
    "style": "tlv"
  },
  {
    "id": "03b4e78b999c4ff....3f",
    "channel": "160....1",
    "direction": 0,
    "msatoshi": 20000,
    "amount_msat": "20000msat",
    "delay": 9,
    "style": "tlv"
  }
]
}
```

### Withdraw funds (outputs) from Lightning to an address of choice

Calls withdraw on lightningd with address and payment parameters supplied.
Withdraws funds to a destination address and Returns the transaction as confirmation.
- `feerate` can be any of: `normal`, `urgent`, `slow`, defaults to `normal`
- `satoshi` can be either a 8 decimal digit representing the amount in BTC or an integer to represent the amount to withdraw in SATOSHI
- `all`  defaults to `false` but if set as `true` will withdraw *all funds* in the lightning wallet.

```http
POST http://192.168.111.152:8080/ln_withdraw
BODY {"destination":"bc1.....xxx","satoshi":"100000","feerate":"normal","all": false}
```
Proxy response:

```json
{
  "tx":"0200000.......f3635e68d4e4fee800000000",
  "txid": "6b38....b0c3b"
}
```
### Stamp a hash on the Bitcoin blockchain using OTS (called by your application)

Will stamp the supplied hash to the Bitcoin blockchain using OTS.  Cyphernode will curl the callback when the OTS stamping is complete.

```http
POST http://cyphernode:8888/ots_stamp
with body...
{"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","callbackUrl":"192.168.111.233:1111/otscallback?id=1234567"}
```

Proxy response:

```json
{
  "method": "ots_stamp",
  "hash": "1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7",
  "id": "422",
  "result": "success"
}
```

```json
{
  "method": "ots_stamp",
  "hash": "1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7",
  "id": "422",
  "result": "error",
  "error": "Error message from OTS client."
}
```

### Wasabi get a new address
Queries random instance for a new bech32 address

```http
POST http://192.168.111.152:8080/wasabi_getnewaddress
BODY {"label":"Pay #12 for 2018"}
BODY {}
```
Empty BODY: Label will be "unknown"
```json

{
  "address": "tb1q....xytp",
  "keyPath": "84'/0'/0'/0/158",
  "label": "[\"Sifir.io deposit\"]"
}
```

### Wasabi Get instance balances

```http
GET http://192.168.111.152:8080/wasabi_getbalances/
GET http://192.168.111.152:8080/wasabi_getbalances/87
```
 If anonset is provided, will return balances for UTXO's with anonset as their minimum Anonimity level.

```json
{
  "0": { "rcvd0conf": 0, "mixing": 10862, "private": 90193, "total": 101055 },
  "all": { "rcvd0conf": 0, "mixing": 10862, "private": 90193, "total": 101055 }
}

```
### Wasabi spend

Spend unused coins from Wasabi wallet
```http
POST http://192.168.111.152:8080/wasabi_spend
BODY {"instanceId":1,"private":true,"amount":0.00103440,"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp", label: "my super private coins", minanonset: 90}
BODY {"amount":0.00103440,"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp"}
```
- instanceId: integer, optional
- private: boolean, optional, default=false
- address: string, required
- amount: number, required
- minanonset: number, optional
- label: number, optional

```json
{
  "message": "success",
  "result": {
    "txid": "",
     "tx": ""
   },
  "event": ""
}
```
### Wasabi get unspent coins

Return all unspent coins of either one wasabi instance or all instances, depending on the instanceId parameter

```http
GET http://192.168.111.152:8080/wasabi_getunspentcoins/{instanceId}
```
args:
 - instanceId: integer, optional

```json
{                                                                                                        
  "instanceId": null,
  "unspentcoins": [{	                                                                                                    
      "txid": "80e48f1.....022118d8",
      "index": 0,     
      "amount": 17701,   
      "anonymitySet": 50,
      "confirmed": true,
      "label": "",                   
      "keyPath": "84'/0'/0'/1/21443",                                                                      
      "address": "tb1qe....p49z"
}]
}
```

### Wasabi get transactions

```http
POST http://192.168.111.152:8080/wasabi_gettransactions/
BODY {"instanceId":1,"txnFilterInternal":true}
```

args:
 - instanceId: integer, optional:  return all transactions of either one wasabi instance or all instances, depending on the instanceId parameter
- txnFilterInternal = true, optional , will only return transcations having a label (label != '')

```json
{                                                                                                                                                                                                                  
  "instanceId": null,                                                                                                                                                                                                
  "transactions": [                                                                                                                                                                                                  
    {                                                                                                                                                                                                              
      "datetime": "2020-04-23T18:10:36+00:00",                                                                                                                                                                       
      "height": 1721643,                                                                                                                                                                                             
      "amount": 340000,                                                                                                                                                                                              
      "label": "mytest",                                                                                                                                                                                             
      "tx": "220850ec4d8a8daf6ebe9e74f4ab29ffca3392ff03a081c4915a83cb56b9e0e5"                                                                                                                                     
    }]
    
}

```

### Wasabi trigger a spendprivate event
Useful to manually trigger an auto-spend
```http
GET http://192.168.111.152:8080/wasabi_spendprivate
```

### Get, Insert or Update Cyphernode config props
Get currently saved configs from propstable
```
GET http://192.168.111.152:8080/config_props
```

```json
[
 { "id": 0, "property": "_cyphernode_prop" ,"value": "awesome" , "inserted_ts": 1593184586 }
]
```
Insert or Update a Cyphernode prop property
```
POST http://192.168.111.152:8080/config_props
BODY { "property": "my_app_config" , "value" : "number go up"}
```
Get currently saved configs from propstable

### Get the OTS file of the supplied hash

Returns the binary OTS file of the supplied hash.  If stamp is complete, will return a complete OTS file, or an incomplete OTS file otherwise.

```http
GET http://cyphernode:8888/ots_getfile/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7
```

Proxy response:

Binary application/octet-stream content type.

### Verify an OTS file

Will verify the supplied OTS file, or verify the local OTS file named after the supplied hash suffixed with .ots.

```http
POST http://cyphernode:8888/ots_verify
with body...
{"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7"}
or
{"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}
```

Proxy response:

```json
{
  "method": "ots_verify",
  "hash": "1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7",
  "result": "success",
  "message": "Message from OTS client."
}
```

```json
{
  "method": "ots_verify",
  "hash": "1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7",
  "result": "pending",
  "message": "Message from OTS client."
}
```

```json
{
  "method": "ots_verify",
  "hash": "1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7",
  "result": "error",
  "message": "Error message from OTS client."
}
```

### Get info an OTS file

Will return the base64 string of the detailed information of the supplied OTS file, or of the local OTS file named after the supplied hash suffixed with .ots.

```http
POST http://cyphernode:8888/ots_info
with body...
{"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7"}
or
{"base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}
or
{"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","base64otsfile":"AE9wZW5UaW1lc3RhbXBzAABQcm9vZ...gABYiWDXPXGQEDxNch"}
```

Proxy response:

```json
{
  "method": "ots_info",
  "result": "success",
  "message": "Base64 string of the information text"
}
```

### Create a batcher

Used to create a batching template, by setting a label and a default confTarget.

```http
POST http://cyphernode:8888/createbatcher
with body...
{"batcherLabel":"lowfees","confTarget":32}
```

Proxy response:

```json
{
  "result": {
    "batcherId": 1
  },
  "error": null
}
```

### Update a batcher

Used to change batching template settings.

```http
POST http://cyphernode:8888/updatebatcher
with body...
{"batcherId":5,"confTarget":12}
or
{"batcherLabel":"fast","confTarget":2}
```

Proxy response:

```json
{
  "result": {
    "batcherId": 1,
    "batcherLabel": "default",
    "confTarget": 6
  },
  "error": null
}
```

### Add an output to the next batched transaction (called by your application)

Inserts output information in the DB.  Used when batchspend is called later.

```http
POST http://cyphernode:8888/addtobatch
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
or
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherId":34,"webhookUrl":"https://myCypherApp:3000/batchExecuted"}
or
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherLabel":"lowfees","webhookUrl":"https://myCypherApp:3000/batchExecuted"}
or
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233,"batcherId":34,"webhookUrl":"https://myCypherApp:3000/batchExecuted"}
```

Proxy response:

```json
{
  "result": {
    "batcherId": 1,
    "outputId": 34,
    "nbOutputs": 7,
    "oldest": "2020-09-09 14:00:01",
    "total": 0.04016971
  },
  "error": null
}
```

### Remove an output from the next batched transaction (called by your application)

Removes a previously added output scheduled for the next batch.

```http
POST http://cyphernode:8888/removefrombatch
with body...
{"outputId":72}
```

Proxy response:

```json
{
  "result": {
    "batcherId": 1,
    "outputId": 72,
    "nbOutputs": 6,
    "oldest": "2020-09-09 14:00:01",
    "total": 0.03783971
  },
  "error": null
}
```

### Spend a batched transaction with outputs previously added with addtobatch (called by your application)

Calls the sendmany RPC on spending wallet with the unspent "addtobatch" inserted outputs.  Will execute default batcher if no batcherId/batcherLabel supplied and default confTarget if no confTarget supplied.

```http
POST http://cyphernode:8888/batchspend
with body...
{}
or
{"batcherId":34}
or
{"batcherId":34,"confTarget":12}
or
{"batcherLabel":"fastest","confTarget":2}
```

Proxy response:

```json
{
  "result": {
    "batcherId":34,
    "confTarget":6,
    "nbOutputs":83,
    "oldest":123123,
    "total":10.86990143,
    "txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
    "hash":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
    "details":{
      "firstseen":123123,
      "size":424,
      "vsize":371,
      "replaceable":true,
      "fee":0.00004112
    },
    "outputs":{
      "1abc":0.12,
      "3abc":0.66,
      "bc1abc":2.848,
      ...
    }
  },
  "error":null
}
```

### Get batcher (called by your application)

Will return current state/summary of the requested batching template.

```http
POST http://cyphernode:8888/getbatcher
with body...
{}
or
{"batcherId":34}
or
{"batcherLabel":"fastest"}
```

Proxy response:

```json
{
  "result": {
    "batcherId": 1,
    "batcherLabel": "default",
    "confTarget": 6,
    "nbOutputs": 12,
    "oldest": 123123,
    "total": 0.86990143
  },
  "error": null
}
```

### Get batch details (called by your application)

Will return current state and details of the requested batch, including all outputs.  A batch is the combination of a batcher and an optional txid.  If no txid is supplied, will return current non-yet-executed batch.

```http
POST http://cyphernode:8888/getbatchdetails
with body...
{}
or
{"batcherId":34}
or
{"batcherLabel":"fastest","txid":"af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648"}
```

Proxy response:

```json
{
  "result": {
    "batcherId": 34,
    "batcherLabel": "Special batcher for a special client",
    "confTarget": 6,
    "nbOutputs": 83,
    "oldest": 123123,
    "total": 10.86990143,
    "txid": "af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
    "hash": "af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648",
    "details": {
      "firstseen": 123123,
      "size": 424,
      "vsize": 371,
      "replaceable":true,
      "fee": 0.00004112
    },
    "outputs": {
      "1abc": 0.12,
      "3abc": 0.66,
      "bc1abc": 2.848,
      ...
    }
  },
  "error": null
}
```

### Get a list of existing batch templates (called by your application)

Will return a list of batch templates.  batcherId 1 is a default batcher created at installation time.

```http
GET http://cyphernode:8888/listbatchers
```

Proxy response:

```json
{
  "result": [
    {"batcherId":1,"batcherLabel":"default","confTarget":6,"nbOutputs":12,"oldest":123123,"total":0.86990143},
    {"batcherId":2,"batcherLabel":"lowfee","confTarget":32,"nbOutputs":44,"oldest":123123,"total":0.49827387},
    {"batcherId":3,"batcherLabel":"highfee","confTarget":2,"nbOutputs":7,"oldest":123123,"total":4.16843782}
  ],
  "error": null
}
```

### Get an estimation of current Bitcoin fees

This will call the Bitcoin Core estimatesmartfee RPC call and return the result as is.

```http
POST http://cyphernode:8888/bitcoin_estimatesmartfee
with body...
{"confTarget":2}
```

Proxy response:

```json
{
  "result": {
    "feerate": 0.00001000,
    "blocks": 4
  },
  "error": null,
  "id": null
}
```
