#!/bin/sh

VERSION=v0.6.0-rc.4

docker build . -t cyphernode/cyphernodeconf:${VERSION}
