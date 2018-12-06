#!/bin/bash

user='nginx'

if [[ $1 ]]; then
	IFS=':' read -ra arr <<< "$1"

	if [[ ${arr[0]} ]]; then
		user=${arr[0]};
	fi

fi

spawn-fcgi -M 0660 -s /var/run/fcgiwrap.socket -u $user -g nginx -U $user -- `which fcgiwrap`
chmod g+rw /var/run/fcgiwrap.socket
nginx -g "daemon off;"
