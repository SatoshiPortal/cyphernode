#!/bin/sh

VERSION=v0.4.0-rc.1

docker build . -t cyphernode/cyphernodeconf:${VERSION}
