# Build image

```shell
docker build -t otsclientimg .
```

# OTS files directory...

```shell
mkdir -p ~/otsfiles
sudo chown -R cyphernode:debian ~/otsfiles ; sudo chmod g+ws ~/otsfiles
sudo find ~/otsfiles -type d -exec chmod 2775 {} \; ; sudo find ~/otsfiles -type f -exec chmod g+rw {} \;
```

# Usefull examples

```shell
curl http://localhost:6666/stamp/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7
curl http://localhost:6666/upgrade/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7
```
