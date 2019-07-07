#!/usr/bin/expect -f

set pw [lindex $argv 1]
set timeout -1
spawn /app/scripts/wasabiCommand.sh [lindex $argv 0]
match_max 100000
expect -exact "Password: "
sleep 1
send -- "$pw\r"
expect eof
