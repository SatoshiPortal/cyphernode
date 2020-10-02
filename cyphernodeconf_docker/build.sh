#!/bin/sh

VERSION=v0.5.0-rc.1

docker build . -t cyphernode/cyphernodeconf:${VERSION}
