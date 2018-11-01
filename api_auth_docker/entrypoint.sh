#!/bin/bash

user='nginx'

if [[ $1 ]]; then
	IFS=':' read -ra arr <<< "$1"

	if [[ ${arr[0]} ]]; then
		user=${arr[0]};
	fi

fi

# create files with -rw-rw----
# this will allow /var/run/fcgiwrap.socket to be accessed rw for group
su -c "umask 0006" $user

spawn-fcgi -M 0660 -s /var/run/fcgiwrap.socket -u $user -g nginx -U $user -- `which fcgiwrap`
nginx -g "daemon off;"
