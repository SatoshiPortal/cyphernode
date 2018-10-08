#!/bin/bash

. ./trace.sh
. ./configure.sh
. ./install.sh

CONFIGURE=0
INSTALL=0
RECREATE=0

while getopts ":cir" opt; do
  case $opt in
    r)
      RECREATE=1
      ;;
    c)
      CONFIGURE=1
      ;;
    i)
      INSTALL=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG. Use -c to configure and -i to install" >&2
      ;;
  esac
done

if [[  $CONFIGURE == 0 && $INSTALL == 0 && RECREATE == 0 ]]; then
    echo "Please use -c to configure, -i to install and -ci to do both. Use -r to recreate config files."
else
  if [[ $CONFIGURE == 1 ]]; then
    trace "Starting configuration phase"
    configure $RECREATE
  fi

  if [[ $INSTALL == 1 ]]; then
    trace "Starting installation phase"
    install
  fi
fi
