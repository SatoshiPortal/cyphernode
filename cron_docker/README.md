# Cyphernode CRON container

## Configure your container by modifying `env.properties` file

```properties
PROXY_URL=cyphernode:8888/executecallbacks
```

## Building docker image

```shell
docker build -t proxycronimg .
```
