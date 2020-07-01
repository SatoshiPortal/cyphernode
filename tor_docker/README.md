# Tor container in Cyphernode

## Pull our Cyphernode image

```shell
docker pull cyphernode/tor:latest
```

## Build yourself the image

```shell
docker build -t cyphernode/tor:latest .
```

## Run image

If you are using it independantly from the Docker stack (docker-compose.yml), you can run it like that:

```shell
docker run --rm -d --network cyphernodenet cyphernode/tor:latest `id -u cyphernode`:`id -g cyphernode` ./tor -f /tor/torrc
```
