# Cyphernode

## Current API

### Watch a Bitcoin Address (called by application)

Inserts the address and callbacks in the DB and imports the address to the Watching wallet.

```http
POST http://cyphernode:8888/watch
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.111.233:1111/callback0conf","confirmedCallbackURL":"192.168.111.233:1111/callback1conf"}
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
    "estimatesmartfee144blocks": "0.000010"
}
```

### Un-watch a previously watched Bitcoin Address (called by application)

Updates the watched address row in DB so that callbacks won't be called on tx confirmations for that address.

```http
GET http://cyphernode:8888/unwatch/2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp
```

Proxy response:

```json
{
  "event": "unwatch",
    "address": "2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp"
}
```

### Get a list of Bitcoin addresses being watched (called by application)

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
  "watching_since":"2018-09-06 21:14:03"}
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
  "is_replaceable":0,
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
  "is_replaceable":0,
  "blockhash":"00000000000000000011bb83bb9bed0f6e131d0d0c903ec3a063e00b3aa00bf6",
  "blocktime":"2018-10-18T16:58:49+0000",
  "blockheight":""
}
```

### Get the Best Block Hash (called by application)

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

### Get Block Info (called by application)

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

### Get the Best Block Info (called by application)

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

### Get a transaction details (node's getrawtransaction) (called by application)

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

### Get spending wallet's balance (called by application)

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

### Get a new Bitcoin address from spending wallet (called by application)

Calls getnewaddress RPC on the spending wallet.  Used to refill the spending wallet from cold wallet (ie Trezor).

```http
GET http://cyphernode:8888/getnewaddress
```

Proxy response:

```json
{
  "address":"2NEC972DZpRM7SfuJUG9rYEix2P9A8qsNKF"
}
```

### Spend coins from spending wallet (called by application)

Calls sendtoaddress RPC on the spending wallet with supplied info.

```http
POST http://cyphernode:8888/spend
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
```

Proxy response:

```json
{
  "status": "accepted",
  "hash": "af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648"
}
```

### Add an output to the next batched transaction (called by application)

Inserts output information in the DB.  Used when batchspend is called later.

```http
POST http://cyphernode:8888/addtobatch
with body...
{"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
```

Proxy response: EMPTY

### Spend a batched transaction with outputs added with addtobatch (called by application)

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

### Get derived address(es) using path in config and provided index (called by application)

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

### Get derived address(es) using provided path and index (called by application)

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

### Get info from Lightning Network node (called by application)

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

### Create a Lightning Network invoice (called by application)

Returns a LN invoice.  Label must be unique.  Description will be used by your user for payment.  Expiry is in seconds.

```http
POST http://cyphernode:8888/ln_create_invoice
with body...
{"msatoshi":10000,"label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":900}
```

Proxy response:

```json
{
  "payment_hash": "fd27edf261d4b089c3478dece4f2c92c8c68db7be3999e89d452d39c083ad00f",
  "expires_at": 1536593926,
  "bolt11": "lntb100n1pdedryzpp5l5n7munp6jcgns683hkwfukf9jxx3kmmuwveazw52tfeczp66q8sdqagfukcmrnyphhyer9wgszxvfsxc6rjxqzuycqp2ak5feh7x7wkkt76uc5ptzcv90jhzhs5swzefv9344hnv74c25dvsstx7l24y46sx5tnkenu480pe06wtly2h5lrj63vszzgrxt4grkcqcltquj"
}
```

### Pay a Lightning Network invoice (called by application)

Make a LN payment.  expected_msatoshi and expected_description are respectively the amount and description you gave your user for her to create the invoice; they must match the given bolt11 invoice supplied by your user.

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

### Get a new Bitcoin address from the Lightning Network node (to fund it) (called by application)

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
