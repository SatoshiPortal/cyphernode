# Bitcoin Core for a custom signet

Image `cyphernode/bitcoin:v32.1-signetblocktime`, used by the installer when
the network is a custom signet whose block time is not 600 seconds (for
example Cyphernet, 30 seconds). Every other setup keeps `cyphernode/bitcoin`.

Bitcoin Core fixes signet's target block spacing at 600 seconds, and the
spacing drives difficulty adjustment: a stock node rejects the blocks of a
faster signet after its first retarget. `signetblocktime.patch` adds
`-signetblocktime=<seconds>`, accepted only together with `-signetchallenge`;
without it the node behaves as stock Bitcoin Core.

The image is built from source, so it is not pulled:

```bash
BUILD_BITCOIN_SIGNET=true ./build.sh
# or
docker build bitcoin_signet_docker/ -t cyphernode/bitcoin:v32.1-signetblocktime
```

In the installer, choose Signet, then Cyphernet or "Another custom signet"
(challenge, block time, seed nodes). The installer writes
`signetchallenge`, `signetblocktime` and `signetseednode` into
`bitcoin.conf`, and its feature test fails when the node follows another
challenge.
