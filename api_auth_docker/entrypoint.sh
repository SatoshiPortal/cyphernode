#!/bin/sh

spawn-fcgi -s /var/run/fcgiwrap.socket -u nginx -g nginx -U nginx -- `which fcgiwrap`

nginx -g "daemon off;"
