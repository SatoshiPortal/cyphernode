#!/bin/sh

VERSION=v0.6.0-dev

docker build . -t cyphernode/cyphernodeconf:${VERSION}
