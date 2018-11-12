# Cyphernode CRON container

## Configure your container by modifying `env.properties` file

```properties
TX_CONF_URL=cyphernode:8888/executecallbacks
OTS_URL=cyphernode:8888/ots_backoffice
```

## Building docker image

```shell
docker build -t proxycronimg .
```
