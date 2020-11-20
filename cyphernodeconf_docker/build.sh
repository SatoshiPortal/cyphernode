#!/bin/sh

VERSION=v0.6.0-rc.1

docker build . -t cyphernode/cyphernodeconf:${VERSION}
