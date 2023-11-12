#!/usr/bin/env sh

dotnet WalletWasabi.Daemon.dll 1>/dev/null 2>&1 &

# wait for dotnet to start
sleep 5

until pids=$(pidof dotnet)
do
    # waiting for dotnet
    sleep 1
done

output=$(curl -s --config ${WASABI_RPC_CFG} -d "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"createwallet\", \"params\":[\"${1}\", \"\"] }" localhost:18099)

echo $output | jq -r '.result' | sed -e 's/"//g'

dotnet_pid=$(pidof dotnet)
kill -TERM $dotnet_pid 1&2>/dev/null

while [ -e /proc/${dotnet_pid} ]; do sleep 1; done
