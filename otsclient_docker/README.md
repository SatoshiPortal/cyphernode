# OTS Client Cyphernode Container

## Pull our Cyphernode image

```shell
docker pull cyphernode/ots:cyphernode-0.05
```

## Build yourself the image

```shell
docker build -t cyphernode/ots:cyphernode-0.05 .
```

## OTS files directory...

```shell
mkdir -p ~/otsfiles
sudo chown -R cyphernode:cyphernode ~/otsfiles ; sudo chmod g+ws ~/otsfiles
sudo find ~/otsfiles -type d -exec chmod 2775 {} \; ; sudo find ~/otsfiles -type f -exec chmod g+rw {} \;
```

## Run image

If you are using it independantly from the Docker stack (docker-compose.yml), you can run it like that:

```shell
docker run --rm -d -p 6666:6666 --network cyphernodenet --env-file env.properties cyphernode/ots:cyphernode-0.05 `id -u cyphernode`:`id -g cyphernode` ./startotsclient.sh
```

## Usefull examples

```shell
curl http://localhost:6666/stamp/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7
curl http://localhost:6666/upgrade/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7
```
