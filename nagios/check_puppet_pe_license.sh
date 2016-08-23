#!/bin/bash -e

#
# Checks the puppet PE license and verifies that:
# - number of nodes are within the license limit
# - license is not due to expire within the next <num> days.
#
# Tested against puppet 4, and runs via Nagios/NRPE, so assumes the current host is the puppetmaster
#

# Defaults
WARNING_NODES="15"
CRITICAL_NODES="5"
WARNING_DAYS="15"
CRITICAL_DAYS="5"

OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage() {
  cat <<-EOF
  Script to check PE license status, for number of nodes remaining under license and number of days before expiry.
  Assumes that the host on which this script is run is the puppetmaster.  Designed to run as an NRPE check, from nagios.

  usage: ${0} [-h] [-w num] [-c num] [-W num] [-C num]

    -h            Usage.
    -w            Number of nodes remaining before a warning alert is triggered.  Default is 15.
    -c            Number of nodes remaining before a critical alert is triggered.  Default is 5.
    -W            Number of days before license expiry before a warning alert is triggered.  Default is 15.
    -C            Number of days before license expiry before a critical alert is triggered.  Default is 5.

  Returns standard Nagios return codes:
  - 0 for success
  - 1 for warning
  - 2 for critical
  - 3 for unknown

EOF
}

while getopts "hw:c:W:C:" opt; do
  case $opt in
    h)
      usage
      exit 3
      ;;
    w)
      WARNING_NODES=$OPTARG
      ;;
    c)
      CRITICAL_NODES=$OPTARG
      ;;
    W)
      WARNING_DAYS=$OPTARG
      ;;
    C)
      CRITICAL_DAYS=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 3
      ;;
  esac
done

#
# Validate the numbers input for warning/critical
#
if [[ $WARNING_NODES != ?(-)+([0-9]) ]] ; then
  echo "UNKNOWN: Invalid value for warning nodes threshold"
  exit $UNKNOWN
fi
if [[ $CRITICAL_NODES != ?(-)+([0-9]) ]] ; then
  echo "UNKNOWN: Invalid value for critical nodes threshold"
  exit $UNKNOWN
fi
if [[ $WARNING_DAYS != ?(-)+([0-9]) ]] ; then
  echo "UNKNOWN: Invalid value for warning days threshold"
  exit $UNKNOWN
fi
if [[ $CRITICAL_DAYS != ?(-)+([0-9]) ]] ; then
  echo "UNKNOWN: Invalid value for critical days threshold"
  exit $UNKNOWN
fi

#
# Get the license text, containing the following:
#
# 'Notice:' You have 5 active 'nodes.' 'Notice:' You are currently licensed for 150 active 'nodes.' 'Notice:' Your support and maintenance agreement ends on '2016-12-13'
#         pos 4 -----^
#                                                                   pos 13 -----^
#                                                                                                                                                pos 25 -----^

LICENSE=$(/usr/local/bin/puppet license)

# Extract the node details
CURRENT_NODES=$(echo $LICENSE | cut -f 4 -d " ")
TOTAL_NODES=$(echo $LICENSE | cut -f 13 -d " ")
NODES_AVAILABLE=$(( $TOTAL_NODES - $CURRENT_NODES ))

# Extract the expiry date details
TODAY=$(date +%s)
EXPIRY_DATE_STR=$(echo $LICENSE | cut -f 24 -d " ")

# This is to remove the trailing console colour codes, eg: '2016-12-13^[[0m'
EXPIRY_DATE_STR=$( echo $EXPIRY_DATE_STR | sed -e "s/\x1b\[.\{1,5\}m//g" )
EXPIRY_DATE=$(date --date="${EXPIRY_DATE_STR}" +%s)
DAYS_BEFORE_EXPIRY=$(( ($EXPIRY_DATE - $TODAY )/(60*60*24) ))

# Construct the return state
MESSAGE="Puppet Enterprise License:: Nodes used $CURRENT_NODES/$TOTAL_NODES. License expires in $DAYS_BEFORE_EXPIRY days, on $EXPIRY_DATE_STR."
if [[ $NODES_AVAILABLE -le $CRITICAL_NODES ]] || [[ $DAYS_BEFORE_EXPIRY -le $CRITICAL_DAYS ]] ; then
  EXIT=$CRITICAL
  STATUS="CRITICAL"
elif [[ $NODES_AVAILABLE -le $WARNING_NODES ]] || [[ $DAYS_BEFORE_EXPIRY -le $WARNING_DAYS ]] ; then
  EXIT=$WARNING
  STATUS="WARNING"
else
  EXIT=$OK
  STATUS="OK"
fi

echo "$STATUS: $MESSAGE | nodes=$CURRENT_NODES;$WARNING_NODES;$CRITICAL_NODES;;"
exit $EXIT

