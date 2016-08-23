#!/bin/bash -e

#
# Checks for the availability of a new puppet PE version.
#
# Tested against puppet 4, and runs via Nagios/NRPE, so assumes the current host is the puppetmaster
#

# Nagios states
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Defaults
ALERT=$WARNING
STATUS="WARNING"

usage() {
  cat <<-EOF
  Script to check for a new Puppet PE version.  Assumes that the host on which this script is run is the puppetmaster.  
  Designed to run as an NRPE check, from nagios.  Type of alert is configurable.  If both flags are set, the last
  listed will take precedence.

  usage: ${0} [-h] [-w num] [-c num] [-W num] [-C num]

    -h            Usage.
    -w            Send warning alert if new version available.  Default.
    -c            Send critical alert if new version available.

  Returns standard Nagios return codes:
  - 0 for success
  - 1 for warning
  - 2 for critical
  - 3 for unknown

EOF
}

while getopts "hwc" opt; do
  case $opt in
    h)
      usage
      exit 3
      ;;
    w)
      ALERT=$WARNING
      STATUS="WARNING"
      ;;
    c)
      ALERT=$CRITICAL
      STATUS="CRITICAL"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 3
      ;;
  esac
done

# This script returns no output if no version updates are available, or
# text as follows when there is a version update:
#    Version 2016.2.0 is now available! (currently 2016.1.2).
#    http://links.puppet.com/enterpriseupgrade
#
VERSION_DATA=$(/opt/puppetlabs/bin/puppet-enterprise-version-check)

if [[ -z $VERSION_DATA ]] ; then
  EXIT=$OK
  MESSAGE="OK:  Puppet PE version is up to date."
else
  EXIT=$ALERT
  MESSAGE="$STATUS: ${VERSION_DATA}"
fi


echo $MESSAGE
exit $EXIT

