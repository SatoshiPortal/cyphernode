#!/bin/sh

VERSION=v0.4.0-rc.2

docker build . -t cyphernode/cyphernodeconf:${VERSION}
