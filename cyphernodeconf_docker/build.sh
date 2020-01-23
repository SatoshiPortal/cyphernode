#!/bin/sh

VERSION=v0.3.0-rc.2

docker build . -t cyphernode/cyphernodeconf:${VERSION}
