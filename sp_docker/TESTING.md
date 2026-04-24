# sp_docker — End-to-End Testing Guide

All commands target the sp service on `localhost:8000`. Adjust the port if `SP_LISTENING_PORT` differs.

The sp service is a **sender**. It sends BTC to a recipient's Silent Payment address, then watches the derived P2TR address for confirmation callbacks. The steps below walk through the full lifecycle: generate a test SP address -> validate it -> watch before or after sending -> simulate wallet notifications -> unwatch.

---

## 1. Generate a test SP address

Run the generator script from inside the sp container:

```bash
eval "$(node --experimental-strip-types scripts/gen-sp-address.ts)"
# sets: SP_ADDRESS, SCAN_PRIVKEY, SPEND_PRIVKEY, SCAN_PUBKEY, SPEND_PUBKEY
echo "SP address: $SP_ADDRESS"
```

Pass `sp` as an argument for a mainnet address:
```bash
eval "$(node --experimental-strip-types scripts/gen-sp-address.ts sp)"
```

---

## 2. Validate the SP address

```bash
curl -s -X POST http://localhost:8000/validatespaddress \
  -H 'content-type: application/json' \
  -d "{\"address\": \"$SP_ADDRESS\"}" | jq
```

---

## 3. Scenario A — Watch before sending

Register a watch first (status `pending`). It activates automatically when the send completes and the derived address becomes known.

### 3a. Create a pending watch

```bash
curl -s -X POST http://localhost:8000/sp_watch \
  -H 'content-type: application/json' \
  -d "{
    \"address\":       \"$SP_ADDRESS\",
    \"callback0conf\": \"http://host.docker.internal:9000/callback\",
    \"callback1conf\": \"http://host.docker.internal:9000/callback\"
  }" | jq
```

### 3b. Send the silent payment

```bash
curl -s -X POST http://localhost:8000/send \
  -H 'content-type: application/json' \
  -d "{
    \"address\":  \"$SP_ADDRESS\",
    \"amount\":   \"0.00003\",
    \"fee_rate\": 2
  }" | jq
```

The pending watch activates automatically when the derived address becomes known. Save the returned values:

```bash
TXID="<txid from response>"
DERIVED="<derived_address from response>"
```

---

## 4. Scenario B — Watch after sending

If you already have a txid, create an active watch directly. Any already-due callbacks fire immediately via RPC.

```bash
curl -s -X POST http://localhost:8000/sp_watch \
  -H 'content-type: application/json' \
  -d "{
    \"address\":       \"$SP_ADDRESS\",
    \"txid\":          \"$TXID\",
    \"callback0conf\": \"http://host.docker.internal:9000/callback\",
    \"callback1conf\": \"http://host.docker.internal:9000/callback\"
  }" | jq
```

---

## 5. List active watches

```bash
curl -s http://localhost:8000/sp_watches | jq
```

---

## 6. Simulate wallet notifications

The `notify_tx` endpoint is called by Bitcoin Core's `walletnotify` hook. The payload is a base64-encoded JSON string matching the `gettransaction` RPC format.

> **Note:** Use `base64 -w 0` (Linux) to suppress line-wrapping. The JSON will be invalid if base64 output is wrapped.

### 0-confirmation (mempool)

```bash
NOTIFY_JSON=$(printf \
  '{"txid":"%s","confirmations":0,"timereceived":1700000000,"fee":-0.00000150,"bip125-replaceable":"no","decoded":{"hash":"%s","size":250,"vsize":150,"vout":[{"scriptPubKey":{"address":"%s"}}]}}' \
  "$TXID" "$TXID" "$DERIVED")

curl -s -X POST http://localhost:8000/notify_tx \
  -H 'content-type: application/json' \
  -d "{\"data\": \"$(echo -n "$NOTIFY_JSON" | base64 -w 0)\"}" | jq
```

### 1-confirmation (block mined)

```bash
NOTIFY_JSON=$(printf \
  '{"txid":"%s","confirmations":1,"blockhash":"00000000abc123","blockheight":101,"blocktime":1700000060,"fee":-0.00000150,"bip125-replaceable":"no","decoded":{"hash":"%s","size":250,"vsize":150,"vout":[{"scriptPubKey":{"address":"%s"}}]}}' \
  "$TXID" "$TXID" "$DERIVED")

curl -s -X POST http://localhost:8000/notify_tx \
  -H 'content-type: application/json' \
  -d "{\"data\": \"$(echo -n "$NOTIFY_JSON" | base64 -w 0)\"}" | jq
```

After both callbacks fire the watch deactivates automatically.

### Verifying callbacks fired

The sp container logs (when `TRACING` is set) record each callback attempt. Check them with:

```bash
docker logs $(docker ps -q --filter "name=sp.1") 2>&1 | grep callback
```

You should see lines like:
```
[sp_watch] callback POST http://... sp_address=tsp1q... derived_address=bcrt1p... confirmations=0
```

If the callback URL returns an error (e.g. nothing is listening on port 9000), that is also logged. To use a real listener during testing, `nc -lk 9000` in another shell will accept connections and print the POST body.

---

## 7. Unwatch manually

Only needed if you want to cancel before both callbacks have fired. At least one callback URL must be provided — only watches where the supplied URL(s) match are deactivated, so multiple parties watching the same SP address with different callback URLs cannot interfere with each other.

```bash
curl -s -X POST http://localhost:8000/sp_unwatch \
  -H 'content-type: application/json' \
  -d "{
    \"address\":       \"$SP_ADDRESS\",
    \"callback0conf\": \"http://host.docker.internal:9000/callback\",
    \"callback1conf\": \"http://host.docker.internal:9000/callback\"
  }" | jq
```
