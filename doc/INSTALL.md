# Cyphernode

## Setting Up

### Installer

We are providing an installer to help you setup Cyphernode.  All the Docker images used by Cyphernode have been prebuilt for x86 and ARM (RPi) architectures and are hosted on the Docker hub public registry, Cyphernode repository (https://hub.docker.com/u/cyphernode/).

You can clone the git repository and install:

```shell
git clone https://github.com/SatoshiPortal/cyphernode.git
cd cyphernode/dist
./setup.sh
```

Or you can simply run this magic command to start setup and installation:

```shell
curl -fsSL https://raw.githubusercontent.com/SatoshiPortal/cyphernode/master/dist/setup.sh -o setup_cyphernode.sh && chmod +x setup_cyphernode.sh && ./setup_cyphernode.sh
```

Note that you can replace "master" in the URL by "dev" or any existing git branch/tag you actually want to install.

### Build cyphernode yourself

You can build cyphernode images yourself.  The images will have the same name than the ones in the docker hub, with the suffix -local.

```shell
git clone https://github.com/SatoshiPortal/cyphernode.git
cd cyphernode
./build.sh
cd dist
./setup.sh
```

`setup.sh` will detect locally built images (with suffix `-local`) and ask you if you want to use them when installing cyphernode.

For full paranoia mode, you can also build yourself all images used by cyphernode but in external repositories by using the `build.sh` script in each of the repo.  You can see a list of images cyphernode uses here: https://cloud.docker.com/u/cyphernode/repository/list

## Upgrading

To upgrade to the most recent version, just get and run the most recent version of the setup.sh file as described in the previous section.  Migration should be taken care by the script.

Your proxy's database won't be lost.  Migration scripts are taking care of automatically migrating the database when starting the proxy.

```
proxy_docker/app/data/sqlmigrate*
```

## Manually test your installation through the Gatekeeper

If you need the authorization header to copy/paste in another tool, put your API ID (id=) and API key (k=) in the following command:

```shell
id="003";key="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";h64=$(echo -n '{"alg":"HS256","typ":"JWT"}' | basenc --base64url | tr -d '=');p64=$(echo -n '{"id":"'${id}'","exp":'$((`date +"%s"`+10))'}' | basenc --base64url | tr -d '=');sig=$(echo -n "${h64}.${p64}" | openssl dgst -hmac "${key}" -sha256 -r -binary | basenc --base64url | tr -d '=');token="${h64}.${p64}.${sig}";echo "Bearer $token"
```

Directly using curl on command line, put your API ID (id=) and API key (k=) in the following commands:

```shell
id="001";key="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";h64=$(echo -n '{"alg":"HS256","typ":"JWT"}' | basenc --base64url | tr -d '=');p64=$(echo -n '{"id":"'${id}'","exp":'$((`date +"%s"`+10))'}' | basenc --base64url | tr -d '=');sig=$(echo -n "${h64}.${p64}" | openssl dgst -hmac "${key}" -sha256 -r -binary | basenc --base64url | tr -d '=');token="${h64}.${p64}.${sig}";curl -v -H "Authorization: Bearer ${token}" -k https://localhost:2009/v0/getbestblockhash
id="003";key="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";h64=$(echo -n '{"alg":"HS256","typ":"JWT"}' | basenc --base64url | tr -d '=');p64=$(echo -n '{"id":"'${id}'","exp":'$((`date +"%s"`+10))'}' | basenc --base64url | tr -d '=');sig=$(echo -n "${h64}.${p64}" | openssl dgst -hmac "${key}" -sha256 -r -binary | basenc --base64url | tr -d '=');token="${h64}.${p64}.${sig}";curl -v -H "Authorization: Bearer ${token}" -k https://localhost:2009/v0/getbalance
id="003";key="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";h64=$(echo -n '{"alg":"HS256","typ":"JWT"}' | basenc --base64url | tr -d '=');p64=$(echo -n '{"id":"'${id}'","exp":'$((`date +"%s"`+10))'}' | basenc --base64url | tr -d '=');sig=$(echo -n "${h64}.${p64}" | openssl dgst -hmac "${key}" -sha256 -r -binary | basenc --base64url | tr -d '=');token="${h64}.${p64}.${sig}";curl -v -H "Authorization: Bearer ${token}" -k https://localhost:2009/v0/ots_stamp
```

## Manually test your installation directly on the Proxy:

```shell
echo "GET /getbestblockinfo" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /getbalance" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /getbestblockhash" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /getblockinfo/00000000a64e0d1ae0c39166f4e8717a672daf3d61bf7bbb41b0f487fcae74d2" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /ln_getinfo" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
```
