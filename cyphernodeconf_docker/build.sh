#!/bin/sh

VERSION=v0.5.0-dev

docker build . -t cyphernode/cyphernodeconf:${VERSION}
