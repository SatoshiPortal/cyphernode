#!/bin/bash

a=$(curl -s --config /tmp/watcher_btcnode_curlcfg.properties -H "Content-Type: application/json" -d '{"method":"echo"}' bitcoin:18332/wallet/watching01.dat | jq -e ".error") ; [ "$?" -ne "0" ] && echo "ready"

curl -d '{"method":"echo"}' bitcoin:18332

echo -n 'f9beb4d9' | xxd -r -p
version\00\00\00\00\00
echo -n "711101000000000000000000c6925e5400000000000000000000000000000000000000000000ffff7f000001208d000000000000000000000000000000000000ffff7f000001208d00000000000000001b2f426974636f696e2e6f7267204578616d706c653a302e392e332f9305050000" | xxd -r -p
"I"



/ $ bitcoin-cli echo ; echo $?
error code: -28
error message:
Loading block index...
28
/ $ bitcoin-cli echo ; echo $?
error code: -28
error message:
Rewinding blocks...
28
/ $ bitcoin-cli echo ; echo $?
error code: -28
error message:
Loading wallet...
28
/ $ bitcoin-cli echo ; echo $?
[
]
0


/ $ a=1 ; while [ "$a" -ne "0" ]; do echo "not ready" ; sleep 2 ; bitcoin-cli echo ; a=$? ; done ; echo "ok"
not ready
[
]
ok

/ $ a=1 ; while [ "$a" -ne "0" ]; do echo "bitcoin not ready" ; sleep 2 ; bitcoin-cli echo ; a=$? ; done ; echo "ok"
not ready
error: Could not connect to the server bitcoin:18332 (error code 1 - "EOF reached")

Make sure the bitcoind server is running and that you are connecting to the correct RPC port.
not ready
error: Could not connect to the server bitcoin:18332 (error code 1 - "EOF reached")

Make sure the bitcoind server is running and that you are connecting to the correct RPC port.
not ready
error: Could not connect to the server bitcoin:18332 (error code 1 - "EOF reached")

Make sure the bitcoind server is running and that you are connecting to the correct RPC port.
not ready
error code: -28
error message:
Verifying wallet(s)...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Loading block index...
not ready
error code: -28
error message:
Rewinding blocks...
not ready
error code: -28
error message:
Rewinding blocks...
not ready
error code: -28
error message:
Rewinding blocks...
not ready
error code: -28
error message:
Loading wallet...
not ready
error code: -28
error message:
Loading P2P addresses...
not ready
[
]
ok
/ $
