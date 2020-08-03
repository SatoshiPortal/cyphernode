#!/usr/bin/env bash
# TODO: get it working without --privileged
docker run -v $(pwd):/ck-bunker/data -p 9823:9823 -it --device /dev/bus/usb --rm cyphernode/ckbunker:latest 0:0 bash
