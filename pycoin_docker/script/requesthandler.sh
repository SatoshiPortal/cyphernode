#!/bin/sh
#
#
#
#

. ./pycoin.sh
. ./responsetoclient.sh
. ./trace.sh
. ./monitoring.sh

GRAFANA_PREFIX=pycoin

main()
{
	trace "Entering main()..."

	local step=0
	local cmd
	local http_method
	local line
	local content_length
	local response
	local returncode

	while read line; do
		line=$(echo "${line}" | tr -d '\r\n')
		trace "[main] line=${line}"

		if [ "${cmd}" = "" ]; then
			# First line!
			# Looking for something like:
			# GET /cmd/params HTTP/1.1
			# POST / HTTP/1.1
			cmd=$(echo "${line}" | cut -d '/' -f2 | cut -d ' ' -f1)
			trace "[main] cmd=${cmd}"
			http_method=$(echo "${line}" | cut -d ' ' -f1)
			trace "[main] http_method=${http_method}"
			monitoring_count "requesthandler.request.${http_method}" 1 $GRAFANA_PREFIX
			if [ "${http_method}" = "GET" ]; then
				step=1
			fi
		fi
		if [ "${line}" = "" ]; then
			trace "[main] empty line"
			if [ ${step} -eq 1 ]; then
				trace "[main] body part finished, disconnecting"
				break
			else
				trace "[main] headers part finished, body incoming"
				step=1
			fi
		fi
		# line=content-length: 406
		case "${line}" in *[cC][oO][nN][tT][eE][nN][tT]-[lL][eE][nN][gG][tT][hH]*)
			content_length=$(echo ${line} | cut -d ':' -f2)
			trace "[main] content_length=${content_length}";
			;;
		esac
		if [ ${step} -eq 1 ]; then
			trace "[main] step=${step}"
			if [ "${http_method}" = "POST" ]; then
				read -n ${content_length} line
				trace "[main] line=${line}"
			fi
			case "${cmd}" in
				derive)
					# POST http://192.168.111.152:7777/derive
					# BODY {"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}
					# BODY {"pub32":"upub5GtUcgGed1aGH4HKQ3vMYrsmLXwmHhS1AeX33ZvDgZiyvkGhNTvGd2TA5Lr4v239Fzjj4ZY48t6wTtXUy2yRgapf37QHgt6KWEZ6bgsCLpb","path":"0/25-30"}
					# BODY {"pub32":"vpub5SLqN2bLY4WeZF3kL4VqiWF1itbf3A6oRrq9aPf16AZMVWYCuN9TxpAZwCzVgW94TNzZPNc9XAHD4As6pdnExBtCDGYRmNJrcJ4eV9hNqcv","path":"0/25-30"}

					response=$(monitor_command $GRAFANA_PREFIX requesthandler.derive derive "${line}")
					response_to_client "${response}" ${?}
					break
					;;
			esac
			break
		fi
	done
	trace "[main] exiting"
	return 0
}

export TRACING

main
exit $?
