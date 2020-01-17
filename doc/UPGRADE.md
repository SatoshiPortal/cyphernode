# Upgrade notes from 0.1 to 0.2, to upgrade manually

Usually no need to do this since it will be done during setup.sh v0.2.

1. cd currentInstallation, where setup.sh is located
2. ./stop.sh current running cyphernode
3. Execute:

```
docker run --rm -it -v "$PWD:/conf" alpine:3.8
apk add --no-cache --update jq curl p7zip
cd conf
7z e config.7z
```

<enter your password>

```
k=$(dd if=/dev/urandom bs=32 count=1 2> /dev/null | xxd -pc 32) && l="kapi_id=\\\"000\\\";kapi_key=\\\"$k\\\";kapi_groups=\\\"stats\\\";eval ugroups_\${kapi_id}=\${kapi_groups};eval ukey_\${kapi_id}=\${kapi_key}" && cat config.json | sed 's/kapi_groups=\\"/kapi_groups=\\"stats,/g' | jq ".gatekeeper_keys.configEntries = [\"$l\"] + .gatekeeper_keys.configEntries" | jq ".gatekeeper_keys.clientInformation = [\"000=$k\"] + .gatekeeper_keys.clientInformation" | jq ".gatekeeper_apiproperties = \"$(curl -fsSL https://raw.githubusercontent.com/SatoshiPortal/cyphernode/v0.2.0/api_auth_docker/api-sample.properties | paste -s -d '\n')\"" > config.json

7z u config.7z config.json
```

<enter your password>
<CTRL-D>

```
curl -fsSL https://raw.githubusercontent.com/SatoshiPortal/cyphernode/v0.2.0/dist/setup.sh -o setup_cyphernode.sh && chmod +x setup_cyphernode.sh && ./setup_cyphernode.sh
```
