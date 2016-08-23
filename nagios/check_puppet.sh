#!/bin/bash -x
#
# Checks that the puppet agent is running and enabled
#

STATE_DIR_3=/var/lib/puppet/state
STATE_DIR_4=/opt/puppetlabs/puppet/cache/state

PROCESS_NAME_3="puppet agent"
PROCESS_NAME_4="pxp-agent"

if [[ -e $STATE_DIR_4 ]]
then
  STATE_DIR=$STATE_DIR_4
  PROCESS_NAME=$PROCESS_NAME_4
else
  STATE_DIR=$STATE_DIR_3
  PROCESS_NAME=$PROCESS_NAME_3
fi

LOCKFILE=$STATE_DIR/agent_disabled.lock

ps auxww | grep -v grep | grep "${PROCESS_NAME}" 1>/dev/null
if (($? > 0)); then
    MESSAGE="Critical: puppet agent process not found!" >&2
    EXIT=2
elif [[ -e $LOCKFILE ]]; then
    DISABLED_MSG=$(cat $STATE_DIR/agent_disabled.lock | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g'| awk 'BEGIN { FS = "|" } ; { print $2 }')
    MESSAGE="Puppet agent disabled! $DISABLED_MSG" >&1
    EXIT=1
else
    MESSAGE="Puppet agent enabled and running"
    EXIT=0
fi

echo "$MESSAGE"
exit $EXIT