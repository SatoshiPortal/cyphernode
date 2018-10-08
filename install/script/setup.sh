#!/bin/sh

. ./trace.sh
. ./configure.sh
. ./install.sh
. ./docker.sh

CONFIGURE=0
INSTALL=0

while getopts ":ci" opt; do
  case $opt in
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

if [[ $CONFIGURE == 1 ]]; then
	echo "Starting configuration phase"
	configure
fi

if [[ $INSTALL == 1 ]]; then
	echo "Starting installation phase"
	install
fi
