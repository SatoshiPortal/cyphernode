#!/bin/sh

VERSION=v0.3.0-rc.3

docker build . -t cyphernode/cyphernodeconf:${VERSION}
