#!/usr/bin/env python

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
# Author: Josie Gioffre                    Email: theblackophelia@gmail.com #
#############################################################################

import requests
import datetime
from optparse import OptionParser
import urllib
import json
import collections
import sys


# Global vars/constants
version='1.0'
total_nodes = 0

PUPPET_V4_API = "pdb/query/v4"
HEADERS = {'Content-Type': 'application/json'}
HTTP_OK = 200

# puppet 4 node states
FAILED = 'failed'
CHANGED = 'changed'
UNCHANGED = 'unchanged'
NOOP = 'noop'
UNRESPONSIVE = 'unresponsive'
UNREPORTED = 'unreported'

node_status_totals = {FAILED:0, CHANGED:0, UNCHANGED:0, NOOP:0, UNRESPONSIVE:0, UNREPORTED:0}
node_status_hosts = {FAILED:[], CHANGED:[], UNCHANGED:[], NOOP:[], UNRESPONSIVE:[], UNREPORTED:[]}

# Nagios states
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3


#
# Construct the base URL for the request
#
def get_base_url():
    return "http://{0}:{1}/{2}/nodes".format(options.hostname, options.port, PUPPET_V4_API)

#
# Determine the return state based on thresholds
#
def status():
    state = ''
    exit = OK;
    if node_status_totals[FAILED] + node_status_totals[UNRESPONSIVE] + node_status_totals[UNREPORTED]  >=  options.critical_threshold:
        status = 'CRITICAL:'
        exit = CRITICAL
    elif node_status_totals[FAILED] + node_status_totals[UNRESPONSIVE] + node_status_totals[UNREPORTED]  >=  options.warning_threshold:
        status = 'WARNING:'
        exit = WARNING
    else:
        status = 'OK:'
        exit = OK

    message = "%s: Total nodes=%s," % (status, str(total_nodes))
    #for state, count in node_status_totals.items():
    for state in sorted(node_status_totals):
        count = node_status_totals[state]
        message += " %s=%s" % (state.title(), str(count))
        if options.detailed and len(node_status_hosts[state]):
            for idx, host in enumerate(node_status_hosts[state]):
                if idx < options.max_hosts:
                    message += " " +  host
                else:
                    message += "..."
                    break
        message += ","

    return exit, message


#
# Gets information from PuppetDB and parses it.  Aggregates the data it needs to determine status
#
def get_node_status():
    global total_nodes

    puppetdb_url = get_base_url()

    response = requests.post(puppetdb_url, headers=HEADERS)
    if response.status_code != HTTP_OK:
        return CRITICAL, "Failed to get a response from PuppetDB: HTTP error code: %s" % response.status_code

    for s in response.json():
        total_nodes +=  1
        node_status_totals[s['latest_report_status']] += 1

        hostname = s['certname'] if options.fqdn_hostnames else s['certname'].split('.')[0]
        node_status_hosts[s['latest_report_status']].append(hostname)

    return status()



def main():
    exit_code, message = get_node_status()
    # This prints the status line picked up by nagios
    print message
    sys.exit(exit_code)



if __name__ == '__main__':

    # Get options
    parser = OptionParser(version=version)
    parser.add_option("-H", "--hostname", action="store", dest="hostname", type="string", help="The PuppetDB hostname (fqdn). eg: dev-puppetmaster-01.mycompany.com")
    parser.add_option("-p", "--port", action="store", dest="port", type="int", default=8080, help="The PuppetDB port. Defaults to 8080")
    parser.add_option("-s", "--summary", action="store_false", dest="detailed",  help="Print summary - just the numbers (not host details)")
    parser.add_option("-d", "--detailed", action="store_true", dest="detailed", default=True, help="Print details - inlcudes host details")
    parser.add_option("-w", "--warning", action="store", dest="warning_threshold", type="int", default="1", help="Warning if <num> hosts are failing. Defaults to 1.")
    parser.add_option("-c", "--critical", action="store", dest="critical_threshold", type="int", default="4", help="Critical if <num> hosts are failing.  Defaults to 4.")
    parser.add_option("-f", "--fqdn", action="store_true", dest="fqdn_hostnames",  help="Show FQDN for hostname, instead of short hostnames.  Default is short hostname.")
    parser.add_option("-m", "--max-hosts", action="store", dest="max_hosts", type="int", default="5", help="Maximum number of host names to display per state.  Default is 5.")

    (options, args) = parser.parse_args()
    if not options.hostname:   # if filename is not given
        parser.error('PuppetDB Hostname not given.')

    main()



