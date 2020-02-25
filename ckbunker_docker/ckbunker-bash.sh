#!/usr/bin/env bash
# TODO: get it working without --privileged
docker run -p 9823:9823 -it --privileged --rm --device /dev/usb/hiddev0 cyphernode/ckbunker:latest 0:0 bash
