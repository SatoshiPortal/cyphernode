#!/usr/bin/env sh

gosu debian-tor tor &
exec gosu $@
