#!/usr/bin/env sh

gosu debian-tor tor &
gosu $@
