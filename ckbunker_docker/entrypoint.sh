#!/usr/bin/env sh

su-exec tor tor &
su-exec $@
