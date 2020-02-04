#!/bin/sh

VERSION=v0.3.0-rc.6

docker build . -t cyphernode/cyphernodeconf:${VERSION}
