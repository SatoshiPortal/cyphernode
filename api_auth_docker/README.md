# HTTP/S API supporting HMAC API keys

So all the other containers are in the Docker Swarm and we want to expose a real HTTP/S interface to clients outside of the Swarm, that makes sense.  Clients have to get an API key first.

## API key

Let's produce a 256-bits key that we'll convert in an hex string to store and use with openssl hmac feature.

```shell
dd if=/dev/urandom bs=32 count=1 2> /dev/null | xxd -pc 32
```

The key is stored in keys.properties and must be given to the client.  This is a secret key.  keys.properties looks like this:

```property
#keyid=hex(key)
key001=2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36
key002=50c5e483b80964595508f214229b014aa6c013594d57d38bcb841093a39f1d83
```

### Bearer token

Following JWT (JSON Web Tokens) standard, we build a bearer token that will be in the request header and signed with the secret key.  We need this in the request header:

```shell
Authorization: Bearer <token>
```

...where token is:

```shell
token = hhh.ppp.sss
```

...where hhh is the header in base64, ppp is the payload in base64 and sss is the signature.  Here are the expected formats and contents:

```shell
header = {"alg":"HS256","typ":"JWT"}
header64 = base64(header) = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9Cg==
```

```shell
payload = {"id":"001","exp":1538528077}
payload64 = base64(payload) = eyJpZCI6IjAwMSIsImV4cCI6MTUzODUyODA3N30K
```

The "id" property is the client id and the "exp" property should be current epoch time + 10 seconds, like:

```shell
$((`date +"%s"`+10))
```

...so that the request will be expired in 10 seconds.  That should take care of most Replay attacks if any.  You should run nginx with TLS so that the replay attack can't be possible.

```shell
signature = hmacsha256(header64.payload64, key)
```

```shell
token = header64 + "." + payload64 + "." + signature
```

### cURL example of an API invocation

Instruction should be in the form:

```shell
curl -v -H "Authorization: Bearer hhh.ppp.sss" localhost
```

10 seconds request expiration:

```shell
id="001";h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" https://localhost/getbestblockhash
```

60 seconds request expiration:

```shell
id="001";h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+60))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" https://localhost/getbestblockhash
```

## SSL

Create your key and certificates.

openssl req -subj '/CN=localhost' -x509 -newkey rsa:4096 -nodes -keyout ~/cyphernode/private/key.pem -out ~/cyphernode/certs/cert.pem -days 365

Use default-ssl.conf as the template instead of default.conf.

## Build

### Create your API key and put it in keys.properties

```shell
dd if=/dev/urandom bs=32 count=1 2> /dev/null | xxd -pc 32
```

### Build and run docker image

```shell
docker build -t authapi .
docker run -d --rm --name authapi -p 80:80 -p 443:443 --network cyphernodenet -v "~/cyphernode/certs:/etc/ssl/certs" -v "~/cyphernode/private:/etc/ssl/private" authapi
```

## Invoke cyphernode through authenticated API

```shell
id="001";h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" https://localhost/getbestblockhash
```

## Technicalities

```shell
h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)
p64=$(echo "{\"id\":\"001\",\"exp\":$((`date +"%s"`+10))}" | base64)
k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36"
s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
token="$h64.$p64.$s"
```
