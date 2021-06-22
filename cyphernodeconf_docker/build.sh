#!/bin/sh

VERSION=v0.7.0-rc.2

docker build . -t cyphernode/cyphernodeconf:${VERSION}
