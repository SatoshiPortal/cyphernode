#!/bin/sh

VERSION=v0.4.0-dev

docker build . -t cyphernode/cyphernodeconf:${VERSION}
