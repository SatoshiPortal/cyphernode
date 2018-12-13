#!/bin/sh
#
#
#
#

. ./otsclient.sh
. ./responsetoclient.sh
. ./trace.sh
. ./monitoring.sh

GRAFANA_PREFIX=otsclient

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
				stamp)
					# GET http://192.168.111.152:8080/stamp/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7

					response=$(monitor_command $GRAFANA_PREFIX requesthandler.stamp stamp $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
					response_to_client "${response}" ${?}
					break
					;;
				upgrade)
					# GET http://192.168.111.152:8080/upgrade/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7

					response=$(monitor_command $GRAFANA_PREFIX requesthandler.upgrade upgrade $(echo "${line}" | cut -d ' ' -f2 | cut -d '/' -f3))
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
