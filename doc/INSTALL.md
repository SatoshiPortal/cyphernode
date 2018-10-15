# Cyphernode

Indirection layer between client and Bitcoin-related services.

Here's the plan:

- The containers are not publicly exposing ports.
- Everything is accessible exclusively within the encrypted overlay network.
- If your system is distributed:
  - ...should be doubly encrypted by an OpenVPN tunnel
  - ...the hosts should be secured and the VPN tunnel should have limited scope by iptables rules on each host.
- We can have different Bitcoin Nodes for watching and spending, giving the flexibility to have different security models one each.
- Only the Proxy has Bitcoin Node RPC credentials.
- The Proxy is exclusively accessible by the Overlay network's containers.
- To manually manage the Proxy (and have access to it), one has to gain access to the Docker host servers as a docker user.
- **Coming soon**: added security to use the spending features of the Proxy with Trezor and Coldcard.

## See [Step-by-step detailed instructions](INSTALL-MANUAL-STEPS.md) for real-world copy-paste standard install instructions

## Setting up

Default setup assumes your Bitcoin Node is already running somewhere.  The reason is that it takes a lot of disk space and often already exists in your infrastructure, why not reusing it.  After all, full blockchain sync takes a while.

You could also just uncomment it in the docker-compose file.  If you run it in pruned mode, say so in config.properties.  The computefees feature won't work in pruned mode.

### Set the swarm
(10.8.0.2 is the host's VPN IP address)

```shell
debian@dev:~/dev/Cyphernode$ docker swarm init --task-history-limit 1 --advertise-addr 10.8.0.2
Swarm initialized: current node (hufy324d291dyakizsuvjd0uw) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-2pxouynn9g8si42e8g9ujwy0v9po45axx367fy0fkjhzo3l1z8-75nirjfkobl7htvpfh986pyz3 10.8.0.2:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

### Create the Overlay Network and make sure your app joins it!
(if your app is not a Docker container, you will have to expose Cyphernode's port and secure it!  In that case, use a reverse proxy with TLS)

```shell
debian@dev:~/dev/Cyphernode$ docker network create --driver=overlay --attachable --opt encrypted cyphernodenet
debian@dev:~/dev/Cyphernode$ docker network connect cyphernodenet yourappcontainer
```

### Configuration

```shell
debian@dev:~/dev/Cyphernode$ vi proxy_docker/env.properties
debian@dev:~/dev/Cyphernode$ vi cron_docker/env.properties
debian@dev:~/dev/Cyphernode$ vi pycoin_docker/env.properties
debian@dev:~/dev/Cyphernode$ vi api_auth_docker/env.properties
```

### Build cron image

[See how to build proxycron image](../cron_docker)

### Build btcproxy image

[See how to build btcproxy image](../proxy_docker)

### Build pycoin image

[See how to build pycoin image](../pycoin_docker)

### Build btcnode image

[See how to build btcnode image](https://github.com/SatoshiPortal/dockers/tree/master/x86_64/bitcoin-core)

### Build clightning image

[See how to build clightning image](https://github.com/SatoshiPortal/dockers/tree/master/x86_64/LN/c-lightning)

### Build the authenticated HTTP API image

[See how to build authapi image](../api_auth_docker)

### Deploy

**Edit docker-compose.yml to specify special deployment constraints or if you want to run the Bitcoin node on the same machine: uncomment corresponding lines.**

```shell
debian@dev:~/dev/Cyphernode$ USER=`id -u cyphernode`:`id -g cyphernode` docker stack deploy --compose-file docker-compose.yml cyphernodestack
Creating service cyphernodestack_authapi
Creating service cyphernodestack_cyphernode
Creating service cyphernodestack_proxycronnode
Creating service cyphernodestack_pycoinnode
Creating service cyphernodestack_clightningnode
```

## Off-site Bitcoin Node

This section is useful if you already have a Bitcoin Core node running and you want to use it in Cyphernode.  In that case, please comment out the btcnode section from docker-compose.yml.

### Join swarm created on Cyphernode server

```shell
pi@SP-BTC01:~ $ docker swarm join --token SWMTKN-1-2pxouynn9g8si42e8g9ujwy0v9po45axx367fy0fkjhzo3l1z8-75nirjfkobl7htvpfh986pyz3 10.8.0.2:2377
```

### Build node container image

[See how to build Bitcoin Node image](https://github.com/SatoshiPortal/dockers/tree/master/rpi/bitcoin-core)

### Connect already-running node

```shell
pi@SP-BTC01:~ $ docker network connect cyphernodenet btcnode
```

## Test deployment from outside of the Swarm

```shell
id="001";h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+1))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -H "Authorization: Bearer $token" -k https://localhost/getbestblockhash
id="003";h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+1))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -H "Authorization: Bearer $token" -k https://localhost/getbalance
```

## Test deployment from any host of the swarm

```shell
echo "GET /getbestblockinfo" | docker run --rm -i --network=cyphernodenet alpine nc cyphernode:8888 -
echo "GET /getbalance" | docker run --rm -i --network=cyphernodenet alpine nc cyphernode:8888 -
echo "GET /getbestblockhash" | docker run --rm -i --network=cyphernodenet alpine nc cyphernode:8888 -
echo "GET /getblockinfo/00000000a64e0d1ae0c39166f4e8717a672daf3d61bf7bbb41b0f487fcae74d2" | docker run --rm -i --network=cyphernodenet alpine nc cyphernode:8888 -
curl -v -H "Content-Type: application/json" -d '{"address":"2MsWyaQ8APbnqasFpWopqUKqsdpiVY3EwLE","amount":0.2}' cyphernode:8888/spend
echo "GET /ln_getinfo" | docker run --rm -i --network=cyphernodenet alpine nc cyphernode:8888 -
echo "GET /ln_newaddr" | docker run --rm -i --network=cyphernodenet alpine nc cyphernode:8888 -
curl -v -H "Content-Type: application/json" -d '{"msatoshi":10000,"label":"koNCcrSvhX3dmyFhW","description":"Bylls order #10649","expiry":900}' cyphernode:8888/ln_create_invoice
curl -v -H "Content-Type: application/json" -d '{"bolt11":"lntb1pdca82tpp5gv8mn5jqlj6xztpnt4r472zcyrwf3y2c3cvm4uzg2gqcnj90f83qdp2gf5hgcm0d9hzqnm4w3kx2apqdaexgetjyq3nwvpcxgcqp2g3d86wwdfvyxcz7kce7d3n26d2rw3wf5tzpm2m5fl2z3mm8msa3xk8nv2y32gmzlhwjved980mcmkgq83u9wafq9n4w28amnmwzujgqpmapcr3","msatoshi":10000,"description":"Bitcoin Outlet order #7082"}' cyphernode:8888/ln_pay
```
