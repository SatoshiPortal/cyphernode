# Here are the exact steps I did to install cyphernode on a debian server running on x86 arch, as user debian.

## Update server and install git

```shell
sudo apt-get update ; sudo apt-get upgrade ; sudo apt-get install git
```

## Docker installation: https://docs.docker.com/install/linux/docker-ce/debian/

```shell
sudo apt-get install      apt-transport-https      ca-certificates      curl      gnupg2      software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository    "deb [arch=amd64] https://download.docker.com/linux/debian \
$(lsb_release -cs) \
stable"
sudo apt-get update
sudo apt-get install docker-ce
sudo groupadd docker
sudo usermod -aG docker $USER
```

CTRL-D (re-login)

## Cyphernode configuration

```shell
docker swarm init --task-history-limit 1
docker network create --driver=overlay --attachable --opt encrypted cyphernodenet
git clone https://github.com/SatoshiPortal/cyphernode.git
cd cyphernode/
vi proxy_docker/env.properties
```

*Make sure user have same rpcuser and rpcpassword values as in bitcoin node's bitcoin.conf file (see below)*

```shell
vi cron_docker/env.properties
vi pycoin_docker/env.properties
vi otsclient_docker/env.properties
vi api_auth_docker/env.properties
```

## Create cyphernode user, create proxy DB folder and build images

```shell
sudo useradd cyphernode
mkdir ~/proxydb ; sudo chown -R cyphernode:cyphernode ~/proxydb ; sudo chmod g+ws ~/proxydb
mkdir -p ~/cyphernode-ssl/certs ~/cyphernode-ssl/private
openssl req -subj '/CN=localhost' -x509 -newkey rsa:4096 -nodes -keyout ~/cyphernode-ssl/private/key.pem -out ~/cyphernode-ssl/certs/cert.pem -days 365
docker build -t authapi api_auth_docker/.
docker build -t proxycronimg cron_docker/.
docker build -t btcproxyimg proxy_docker/.
docker build -t pycoinimg pycoin_docker/.
docker build -t otsclientimg otsclient_docker/.
```

## Build images from Satoshi Portal's dockers repo
(For cyphernode, we are using host user cyphernode for all containers)

```shell
cd ..
git clone https://github.com/SatoshiPortal/dockers.git
cd dockers/x86_64/LN/c-lightning/
vi bitcoin.conf
```

*Make sure testnet, rpcuser and rpcpassword have the same value as in bitcoin node's bitcoin.conf file (see below)*

```console
rpcconnect=bitcoin
rpcuser=rpc_username
rpcpassword=rpc_password
testnet=1
rpcwallet=ln01.dat
```

```shell
vi config
mkdir ~/lndata
cp config ~/lndata/
sudo chown -R cyphernode:cyphernode ~/lndata ; sudo chmod g+ws ~/lndata
sudo find ~/lndata -type d -exec chmod 2775 {} \; ; sudo find ~/lndata -type f -exec chmod g+rw {} \;
docker build -t clnimg .
cd ../../bitcoin-core/
mkdir ~/btcdata
sudo chown -R cyphernode:cyphernode ~/btcdata ; sudo chmod g+ws ~/btcdata
sudo find ~/btcdata -type d -exec chmod 2775 {} \; ; sudo find ~/btcdata -type f -exec chmod g+rw {} \;
docker build -t btcnode .
mkdir ~/otsfiles
sudo chown -R cyphernode:cyphernode ~/otsfiles ; sudo chmod g+ws ~/otsfiles
sudo find ~/otsfiles -type d -exec chmod 2775 {} \; ; sudo find ~/otsfiles -type f -exec chmod g+rw {} \;
```

## Mount bitcoin data volume and make sure bitcoin configuration is ok
(I already had a bitcoin volume with blocks and chainstate folders sync'ed)
(Watcher and spender is the same bitcoin node, with different wallets)

```shell
sudo mount /dev/vdc ~/btcdata/
vi ~/btcdata/bitcoin.conf
```

*Make sure testnet, rpcuser and rpcpassword have the same value as in c-lightning node's bitcoin.conf file (see above)*

```console
testnet=1
txindex=1
rpcuser=rpc_username
rpcpassword=rpc_password
rpcallowip=10.0.0.0/24
#printtoconsole=1
maxmempool=64
dbcache=64
zmqpubrawblock=tcp://0.0.0.0:29000
zmqpubrawtx=tcp://0.0.0.0:29000
wallet=watching01.dat
wallet=spending01.dat
wallet=ln01.dat
walletnotify=curl proxy:8888/conf/%s
```

## Deploy the cyphernode stack

```shell
cd ~/cyphernode/
USER=`id -u cyphernode`:`id -g cyphernode` docker stack deploy --compose-file docker-compose.yml cyphernode
```

## Wait a few minutes and re-apply permissions

```shell
sudo chown -R cyphernode:cyphernode ~/lndata ; sudo chmod g+ws ~/lndata
sudo chown -R cyphernode:cyphernode ~/btcdata ; sudo chmod g+ws ~/btcdata
sudo find ~/lndata -type d -exec chmod 2775 {} \; ; sudo find ~/lndata -type f -exec chmod g+rw {} \;
sudo find ~/btcdata -type d -exec chmod 2775 {} \; ; sudo find ~/btcdata -type f -exec chmod g+rw {} \;
  ```

## Test the deployment

```shell
id="001";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" -k https://127.0.0.1/getbestblockhash
id="003";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" -k https://127.0.0.1/getbalance
id="003";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Content-Type: application/json" -d '{"hash":"123","callbackUrl":"http://callback"}' -H "Authorization: Bearer $token" -k https://127.0.0.1/ots_stamp
```

If you need the authorization header to copy/paste in another tool:

```shell
id="003";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+30))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";echo "Bearer $token"
```

```shell
echo "GET /getbestblockinfo" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /getbalance" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
echo "GET /ln_getinfo" | docker run --rm -i --network=cyphernodenet alpine nc proxy:8888 -
docker exec -it `docker ps -q -f name=cyphernodestack_cyphernode` curl -H "Content-Type: application/json" -d "{\"pub32\":\"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb\",\"path\":\"0/25-30\"}" proxy:8888/derivepubpath
```
