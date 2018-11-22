# HTTP/S API supporting HMAC API keys

So all the other containers are in the Docker Swarm and we want to expose a real HTTP/S interface to clients outside of the Swarm, that makes sense.  Clients have to get an API key first.

## Pull our Cyphernode image

```shell
docker pull cyphernode/gatekeeper:cyphernode-0.05
```

## Build yourself the image

```shell
docker build -t cyphernode/gatekeeper:cyphernode-0.05 .
```

## Run image

If you are using it independantly from the Docker stack (docker-compose.yml), you can run it like that:

```shell
docker run -d --rm --name gatekeeper -p 80:80 -p 443:443 --network cyphernodenet -v "~/cyphernode-ssl/certs:/etc/ssl/certs" -v "~/cyphernode-ssl/private:/etc/ssl/private" --env-file env.properties cyphernode/gatekeeper:cyphernode-0.05 `id -u cyphernode`:`id -g cyphernode`
```

## Prepare

### Create your API key and put it in keys.properties

Let's produce a 256-bits key that we'll convert in an hex string to store and use with openssl hmac feature.

Alpine (Busybox):

```shell
dd if=/dev/urandom bs=32 count=1 2> /dev/null | xxd -pc 32
```

Linux:

```shell
dd if=/dev/urandom bs=32 count=1 2> /dev/null | xxd -ps -c 32
```

Put the id, key and groups in keys.properties and give the id and key to the client.  The key is a secret.  keys.properties looks like this:

```property
#kappiid="id";kapi_key="key";kapi_groups="group1,group2";leave the rest intact
kapi_id="001";kapi_key="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";kapi_groups="watcher";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
kapi_id="002";kapi_key="50c5e483b80964595508f214229b014aa6c013594d57d38bcb841093a39f1d83";kapi_groups="watcher";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
kapi_id="003";kapi_key="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";kapi_groups="watcher,spender";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
kapi_id="004";kapi_key="bb0458b705e774c0c9622efaccfe573aa30c82f62386d9435f04e9727cdc26fd";kapi_groups="watcher,spender";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
kapi_id="005";kapi_key="6c009201b123e8c24c6b74590de28c0c96f3287e88cac9460a2173a53d73fb87";kapi_groups="watcher,spender,admin";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
kapi_id="006";kapi_key="19e121b698014fac638f772c4ff5775a738856bf6cbdef0dc88971059c69da4b";kapi_groups="watcher,spender,admin";eval ugroups_${kapi_id}=${kapi_groups};eval ukey_${kapi_id}=${kapi_key}
```

You can have multiple keys, but be aware that this container has **not** been built to support thousands of API keys!  **Cyphernode should be used locally**, not publicly as a service.

## IP Addresses Whitelist (**do not use for now**)
**Docker Swarm obfuscates real client IP, this feature is not ready for now**

You can have an IP whitelist policy, denying everything except the explicit IP addresses you need.  Edit ip-whitelist.conf file:

```conf
# Leave commented if you don't want to use IP whitelist

# List of white listed IP addresses...
#allow 45.56.67.78;
#deny all;
```

## SSL

If you already have your certificates and keystores infra, you already know what to do and your can skip this section.  Put your files in the bound volume (~/cyphernode-ssl/ see volume path in docker-compose.yml).

If not, you can create your keys and self-signed certificates.

```shell
mkdir -p ~/cyphernode-ssl/certs ~/cyphernode-ssl/private
openssl req -subj '/CN=localhost' -x509 -newkey rsa:4096 -nodes -keyout ~/cyphernode-ssl/private/key.pem -out ~/cyphernode-ssl/certs/cert.pem -days 365
```

If you don't want to use HTTPS, just copy default.conf instead of default-ssl.conf in Dockerfile.

**Nota bene**: If you self-sign the certificate, you have to trust the certificate on the client side by adding it to the Trusted Root Certification Authorities or whatever your client needs.

### Build and run docker image

```shell
docker build -t authapi .
```

If you are using it independantly from the Docker stack (docker-compose.yml), you can run it like that:

```shell
docker run -d --rm --name authapi -p 80:80 -p 443:443 --network cyphernodenet -v "~/cyphernode-ssl/certs:/etc/ssl/certs" -v "~/cyphernode-ssl/private:/etc/ssl/private" authapi
```

## FYI: Bearer token

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
id="001";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" -k https://localhost/getbestblockhash
```

60 seconds request expiration:

```shell
id="001";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+60))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" -k https://localhost/getbestblockhash
```

## Technicalities

```shell
h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64)
p64=$(echo -n "{\"id\":\"001\",\"exp\":$((`date +"%s"`+10))}" | base64)
k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36"
s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1)
token="$h64.$p64.$s"
```
