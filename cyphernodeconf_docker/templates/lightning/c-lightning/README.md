# How to create the hmac for the cookie file:

```
# echo -n "access-key" | openssl dgst -hmac "cyphernode:sparkwallet" -sha256 -binary | base64 | sed 's/[\+\W]//g'
```
