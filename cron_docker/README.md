# Cyphernode CRON container

## Pull our Cyphernode image

```shell
docker pull cyphernode/proxycron:latest
```

## Build yourself the image

```shell
docker build -t cyphernode/proxycron:latest .
```

## Run image

If you are using it independantly from the Docker stack (docker-compose.yml), you can run it like that:

```shell
docker run --rm -d --network cyphernodenet --env-file env.properties cyphernode/proxycron:latest
```

## Configure your container by modifying `env.properties` file

```properties
TX_CONF_URL=cyphernode:8888/executecallbacks
OTS_URL=cyphernode:8888/ots_backoffice
```
