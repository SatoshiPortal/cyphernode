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