#!/bin/bash

(cd install/script && TRACING=1 ./setup.sh $@)

# Execute this on a freshly install ubuntu luna node
# curl -fsSL get.docker.com -o get-docker.sh
# sh get-docker.sh
# sudo usermod -aG docker $USER
# logout and relogin
# git clone --branch features/install --recursive https://github.com/schulterklopfer/cyphernode.git
# sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# sudo chmod +x /usr/local/bin/docker-compose
# cd cyphermode
# ./setup.sh -ci
# docker-compose -f docker-compose.yaml up [-d]