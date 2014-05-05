#!/bin/bash

#############################################################################
#                                                                           #
# This script was initially developed by Infoxchange for internal use       #
# and has kindly been made available to the Open Source community for       #
# redistribution and further development under the terms of the             #
# GNU General Public License v3: http://www.gnu.org/licenses/gpl.html       #
#                                                                           #
#############################################################################
#                                                                           #
# This script is supplied 'as-is', in the hope that it will be useful, but  #
# neither Infoxchange nor the authors make any warranties or guarantees     #
# as to its correct operation, including its intended function.             #
#                                                                           #
# Or in other words:                                                        #
#       Test it yourself, and make sure it works for YOU.                   #
#                                                                           #
#############################################################################
# Author: George Hansper                     e-mail:  george@hansper.id.au  #
#############################################################################

TIMEOUT=30
TIME_WARN=5
TIME_CRIT=10
HOST=`hostname --fqdn`
PUPPETMASTER=puppetmaster
PORT=8140
SSLDIR=/var/lib/puppet/ssl

OPTS=`getopt -o ht:H:p:w:c: --long hostname:,timeout:,port:,warn:,crit: \
     -n '$0' -- "$@"`

function usage () {
	cat <<-EOF
		Usage: $0 [ -h ] [ --help ] [ -H hostname ] [ --hostname hostname ]
		          [ -w decimal ] [ --warn decimal ] [ -c decimal ] [ --crit decimal ]
		          [ -t integer ] [ --timeout integer ]
		   -H, --hostname ... name of puppetmaster host (default is $PUPPETMASTER)
		   -w, --warn     ... Warning  if check takss longer than this many seconds (floating point, default is $TIME_WARN)
		   -c, --crit     ... Critical if check takss longer than this many seconds (floating point, default is $TIME_CRIT)
		   -t, --timeout  ... timeout for this check (integer, default is $TIMEOUT)
		   -p, --port     ... port number (default is $PORT)

		Example
		        $0 --warn 2 --crit 3.5 --timeout 60

		Notes
		        This check must be run on a host that is a client of the puppetmaster being checked.
		        It will look for the key and certificates in the directory $SSLDIR

		        In order to read the hosts's private key, this script needs to be run under sudo as the user puppet (or root)
		        Sample Configuration:

		            /etc/sudoers
		               nagios  ALL=(puppet) NOPASSWD: /usr/lib/nagios/plugins/check_puppetmaster.sh

		            /etc/nagios/commands.cfg entry
		               define command {
		                     command_name       check_puppetmaster
		                     command_line       /usr/bin/sudo /usr/lib/nagios/plugins/check_puppetmaster.sh -H \$HOSTNAME\$ \$ARG1\$
		               }

EOF
}

if [ $? != 0 ] ; then
	echo "Terminating..." >&2
	usage
  exit 1
fi
eval set -- "$OPTS"

# This command has to run under sudo - so we need to check the args carefully in case of character-injection (eg ;)
while true ; do
	case "$1" in
		-h|--help)
			usage
			exit
			;;
		-H|--hostname)
			PUPPETMASTER=$( echo $2 |sed -e 's/[^-0-9a-z._]//ig')
			shift 2
			;;
		-w|--warn)
			TIME_WARN=$( echo $2 |sed -e 's/[^0-9.]//g')
			shift 2
			;;
		-c|--crit)
			TIME_CRIT=$( echo $2 |sed -e 's/[^0-9.]//g')
			shift 2
			;;
		-t|--timeout)
			# We accept floating point, but truncate to integer for curl
			TIMEOUT=$( echo $2 |sed -e 's/[^0-9.]//g; s/\..*//; s/^0$/1/')
			shift 2
			;;
		-p|--port)
			PORT=$( echo $2 |sed -e 's/[^0-9]//g')
			shift 2
			;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

URL="https://${PUPPETMASTER}:${PORT}/production/node/${HOST}"
T1=`date +%s.%N`
CURL_NODE="`curl -sS --max-time $TIMEOUT --insecure -H 'Accept: yaml'  --cert $SSLDIR/certs/${HOST}.pem  --key $SSLDIR/private_keys/${HOST}.pem  --cacert $SSLDIR/certs/ca.pem "${URL}" 2>&1`"
CURL_RESULT=$?
T2=`date +%s.%N`

PERF_TIME=$( perl -e "printf('%1.3f', $T2 - $T1);" )

if [ "$CURL_RESULT" != 0 ]; then
	EXIT=2
	MESSAGE="${URL} $CURL_NODE"
elif FOUND=$( echo "$CURL_NODE" | grep -m 1 environment: ) ; then
	# trim spaces...
	FOUND=`sed 's/^  *.//' <<<$FOUND`
	EXIT=0
	MESSAGE="found '${FOUND}' in https://${PUPPETMASTER}:${PORT}/production/node/${HOST}"
else
	EXIT=1
	MESSAGE="environment not found in https://${PUPPETMASTER}:${PORT}/production/node/${HOST}"
fi

if ! perl -e "exit( $PERF_TIME >= $TIME_CRIT )" ; then
	MESSAGE="Response time $PERF_TIME>=$TIME_CRIT - $MESSAGE"
	EXIT=$(( $EXIT | 2 ))
elif ! perl -e "exit( $PERF_TIME >= $TIME_WARN )" ; then
	MESSAGE="Response time $PERF_TIME>=$TIME_WARN - $MESSAGE"
	EXIT=$(( $EXIT | 1 ))
else
	MESSAGE="Response time ${PERF_TIME}s - $MESSAGE"
fi

case "$EXIT" in
	0) MESSAGE="OK: $MESSAGE" ;;
	1) MESSAGE="Warning: $MESSAGE" ;;
	2|3) MESSAGE="Critical: $MESSAGE" ; EXIT=2;;
esac

echo "$MESSAGE|time=${PERF_TIME}s;$TIME_WARN;$TIME_CRIT;0"
exit $EXIT
