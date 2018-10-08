#!/bin/sh

. ./trace.sh
. ./configure.sh
. ./install.sh

echo "Starting configuration phase"
configure

echo "Starting installation phase"
install