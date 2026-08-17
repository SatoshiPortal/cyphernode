# Paymentalist Docker

This repository contains the Paymentalist web service for interacting with Boltz payment hints.

## Building the Container

To build the container, run:

```bash
docker build -t paymentalist .
```

## Running the Reverse Swap Test Helper

The source tree includes a development/test utility for creating reverse swaps. It is not shipped in the production runtime image because it uses test-only wallet material. To use it from this directory:

```bash
cargo run --bin create_reverse_swap -- [OPTIONS]
```

### Available Options

- `-n, --network <NETWORK>`: The network to use (mainnet or testnet)
  - Default: mainnet
  - Example: `-n testnet`

- `-c, --claim-address <ADDRESS>`: The claim address for the swap (required)
  - Example: `-c lq1qqd4etnrx4hptrg94j3826lyzmqa78p7et8k52khv0cv948vxeauy96kty8ere8xdjd08x70qvua39tpt8n366m7lu25yd0ker`

- `-i, --invoice-amount <AMOUNT>`: The invoice amount in satoshis
  - Default: 1000
  - Example: `-i 5000`

### Example Usage

Create a reverse swap on mainnet:
```bash
cargo run --bin create_reverse_swap -- \
  -n mainnet \
  -c lq1qqd4etnrx4hptrg94j3826lyzmqa78p7et8k52khv0cv948vxeauy96kty8ere8xdjd08x70qvua39tpt8n366m7lu25yd0ker \
  -i 1000
```

Create a reverse swap on testnet:
```bash
cargo run --bin create_reverse_swap -- \
  -n testnet \
  -c YOUR_TESTNET_ADDRESS \
  -i 1000
```

### Output

The script will output:
1. A validation message
2. The reverse swap ID
3. The invoice that needs to be paid

## Notes

- The helper uses a hardcoded mnemonic for testing purposes and is not included in the production Docker image.
- Make sure to use the correct network (mainnet/testnet) that matches your claim address.
- The claim address must be a valid Liquid address for the specified network.

## Example
```
cargo run --bin create_reverse_swap -- --network testnet --claim-address tlq1qqtzkefxathskcl5svkfwscd6eyhua8f8v9snpxdy7fe8lu3x6c0v93k3stc4e79avd4d9z76vm30yc3564z6wl5wcs2v409fl  --invoice-amount 1000
VALIDATED RESPONSE!
REVERSE SWAP ID: DxQkFTua5pA3
INVOICE: lntb10u1p5qve7ssp5gwtmd79va4x3cpta689c0p0mahz0zmnky8usk50uk33agdfxc0zspp5eqraufs5xkk0ztxfsswdksv0t6a32dekahtfd3run773ed22w30qdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvxqyp2xqcqz95rzjqt8lh9k5dfmdd3kfrvdd682u0gjvat79rld78d5223fnwltzcslf6zzxeyqq28qqqqqqqqqqqqqqq9gq2y9qyysgqhcvdlclcthfegu4rt24n8jqcn8pcewu8wp7v7x7ejpevu9y5ycx9uy2ppruyknmd2jpjmzx8fudls57ngepp2c5xddlm7d05jsetsdqpqc28at
```


# Paymentalist Web Service

```bash
curl -X POST http://paymentalist:8080/check_bolt11_mrh \
  -H "Content-Type: application/json" \
  -d '{"invoice":"lnbc11110n1pnlfshcsp5dtzgydc0nfxdvznw4h87afa0nfrr8agc2807fpxcmva6m5q4qdtqpp5vd98catyj6eclaqf9rwjj3plyrk7t8pc3gzrhg4t6n0q8ndyk5wqdqhfehjq3r9wd3hy6tsw35k7msxqyp2xqcqz95rzjqgnan5zzk7rq88mtl4vqem7uedqde34zgh9e8e3jg63yufgjnhzl7zzxeyqq28qqqqqqqqqqqqqqq9gq2y9qyysgq2r73mthfs223rjl4jgmwl3lp9gwe6dmk2unjkd08edn65zhhefzze58wjzucwduzat4cct47leacuzf449a9zyjnafkytggq8y4mvcsqsawr3a", "network":"bitcoin"}'
```

This sends a POST request with:

1. The BOLT11 invoice as a string
2. An optional network parameter (bitcoin mainnet in this example)

## Expected Response

```json
{
  "liquid_address": "bc1qexample...",  // Only present if magic routing hint found
  "amount_sats": 10000,                // Only present if magic routing hint found
  "original_invoice": "lnbc100u1pjq5dx4...",
}
```

Example going through proxy rather than paymentalist directly:
```bash
curl -X POST http://localhost:8888/check_bolt11_mrh \
  -H "Content-Type: application/json" \
  -d '{"bolt11":"lnbc11110n1pnlfshcsp5dtzgydc0nfxdvznw4h87afa0nfrr8agc2807fpxcmva6m5q4qdtqpp5vd98catyj6eclaqf9rwjj3plyrk7t8pc3gzrhg4t6n0q8ndyk5wqdqhfehjq3r9wd3hy6tsw35k7msxqyp2xqcqz95rzjqgnan5zzk7rq88mtl4vqem7uedqde34zgh9e8e3jg63yufgjnhzl7zzxeyqq28qqqqqqqqqqqqqqq9gq2y9qyysgq2r73mthfs223rjl4jgmwl3lp9gwe6dmk2unjkd08edn65zhhefzze58wjzucwduzat4cct47leacuzf449a9zyjnafkytggq8y4mvcsqsawr3a", "network":"bitcoin"}' | jq
```
