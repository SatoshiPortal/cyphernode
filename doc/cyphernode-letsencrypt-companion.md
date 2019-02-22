# Cyphernode + Let's Encrypt Companion

Cyphernode has been built with a low-traffic semi-trusted usage in mind.  Expose it to the outside world at your own risk and peril.

## Install Cyphernode

```
cd ; git clone https://github.com/SatoshiPortal/cyphernode.git
cd cyphernode/
git checkout features/lnfeats
```

### Adjust Cyphernode docker-compose

```
vi install/generator-cyphernode/generators/app/templates/installer/docker/docker-compose.yaml
```

(add environment in gatekeeper)
```
      - "VIRTUAL_PROTO=https"
      - "VIRTUAL_HOST=cyphernode.yourdomain.com"
      - "VIRTUAL_PORT=443"
      - "LETSENCRYPT_HOST=cyphernode.yourdomain.com"
      - "LETSENCRYPT_EMAIL=you@yourdomain.com"
```

```
./build.sh
./dist/setup.sh
```

(choose a different port for the gatekeeper, 443 will be used by the letsencrypt companion)

## Install docker-compose

```
sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

## Install and start letsencypt-companion

```
cd ; git clone https://github.com/buchdag/letsencrypt-nginx-proxy-companion-compose.git
cd letsencrypt-nginx-proxy-companion-compose/2-containers/compose-v3/labels/
vi docker-compose.yaml
```

(change network to cyphernodenet)

```
docker-compose up -d
```

## Start Cyphernode

```
cd ~/cyphernode/dist/
./start.sh
```

## Web access Cyphernode

https://cyphernode.yourdomain.com/status
