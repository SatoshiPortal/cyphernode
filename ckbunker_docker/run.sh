#!/usr/bin/env bash

docker run -p 9823:9823 --rm --device /dev/usb/hiddev0 cyphernode/ckbunker:latest 0:0 ck-bunker run
