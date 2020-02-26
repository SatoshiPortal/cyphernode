#!/bin/sh

VERSION=v0.3.1-rc.1

docker build . -t cyphernode/cyphernodeconf:${VERSION}
