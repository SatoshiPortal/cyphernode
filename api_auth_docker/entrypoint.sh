#!/bin/bash

while [ ! -f "/container_monitor/proxy_ready" ]; do echo "proxy not ready" ; sleep 10 ; done

echo "proxy ready"

if [[ $1 ]]; then
	user=$(echo $1 | cut -d ':' -f 1)
else
	user='nginx'
fi

spawn-fcgi -M 0660 -s /var/run/fcgiwrap.socket -u $user -g nginx -U $user -- `which fcgiwrap`
chmod -R g+rw /var/run/fcgiwrap.socket /etc/nginx/conf.d/*
chown -R :nginx /etc/nginx/conf.d/*
exec nginx -g "daemon off;"
