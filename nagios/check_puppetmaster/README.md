
opstools/nagios/check_puppetmaster
==================================

* check_puppetmaster.sh - Nagios Plugin (Bash Script)


This Nagios Plugin is made for a Puppet-controlled environment.

It sends a https request to the puppetmaster, and looks for the string 'environment:' in the result.

It requires that the host running the check is a client of the puppetmaster, as it uses SSL user certificates to authenticate to the puppetmaster.

This check uses the command 'curl' to access the puppetmaster.

The plugin reports the time taken to execute the curl command, and provides this as performance data (for eg. pnp4nagios)

Installation & Configuration
----------------------------

This plugin needs to run as the user puppet or root, in order to access the SSL private key in /var/lib/puppet/ssl

Example configuration

/etc/sudoers
	nagios  ALL=(puppet) NOPASSWD: /usr/lib/nagios/plugins/check_puppetmaster.sh

/etc/nagios/commands.cfg (fragment)
	define command {
	     command_name       check_puppetmaster
	     command_line       /usr/bin/sudo -u puppet /usr/lib/nagios/plugins/check_puppetmaster.sh -H $HOSTNAME$ $ARG1$
	}

/etc/nagios/services.cfg (fragment, typical)
	define service {
		use                             generic-service
		host_name                       my-puppetmaster
		service_description             puppetmaster
		check_command                   check_puppetmaster!-w 2
	}

PNP4Nagios
----------
No pnp4nagios template is required, the default configuration works properly.

Other Requirements
------------------

Packages required by this plugin:

	curl

Sample Output
-------------

# sudo -u puppet /usr/lib/nagios/plugins/check_puppetmaster.sh -H my-puppetmaster
OK: Response time 1.068s - found 'environment: production' in https://my-puppetmaster:8140/production/node/my-nagios.local|time=1.068s;5;10;0

# sudo -u puppet /usr/lib/nagios/plugins/check_puppetmaster.sh -H my-puppetmaster -w 0.5 -c 2.0
Warning: Response time 1.055>=0.5 - found 'environment: production' in https://my-puppetmaster:8140/production/node/my-nagios.local|time=1.055s;0.5;2.0;0

# sudo -u puppet /usr/lib/nagios/plugins/check_puppetmaster.sh -H my-puppetmaster -w 0.5 -c 2.0
Critical: Response time 2.215>=2.0 - found 'environment: production' in https://my-puppetmaster:8140/production/node/my-nagios.local|time=2.215s;0.5;2.0;0

# sudo -u puppet /usr/lib/nagios/plugins/check_puppetmaster.sh -H my-puppetmaster -w 0.5 -c 1.0 -t 1
Critical: Response time 1.016>=1.0 - https://my-puppetmaster:8140/production/node/my-nagios.local curl: (28) Operation timed out after 1001 milliseconds with 0 bytes received|time=1.016s;0.5;1.0;0
