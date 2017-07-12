opstools/nagios/check_newrelic
==============================

* check_newrelic.pl - Nagios Plugin (Perl Script)


This Nagios Plugin is made for users of NewRelic http://newrelic.com

The plugin queries the NewRelic API, and reports on:
* applications performance metrics
* any Apdex or Error-rate alerts, as defined in NewRelic

It requires that the application has thresholds defined for Apdex and Error rate in NewRelic.
If no thresholds are defined, the plugin will always report OK.

The statistics from NewRelic are presented as Nagios performance data, suitable for graphing with PNP4Nagios.

Installation & Configuration
----------------------------

In NewRelic, create an API Key on the NewRelic website https://rpm.newrelic.com
	Newrelic > Account settings > Integrations > Data Sharing > API access.

For more information, see:
	https://newrelic.com/docs/features/getting-started-with-the-new-relic-rest-api

Copy the plugin to:
	nagios-server:/usr/lib/nagios/plugins/check_newrelic.pl

In the usual *.cfg files:

	define command {
		command_name    check_newrelic
		command_line    /usr/lib/nagios/plugins/check_newrelic.pl -H $HOSTNAME$ -k putyourapikeyhere $ARG1$
	}

	define host {
		use		generic-host
		host_name	api.newrelic.com
		alias		api.newrelic.com
		address		api.newrelic.com
	}

	define service{
		use			generic-service
		host_name		api.newrelic.com
		service_description	mycoolwebsite
		check_command		check_newrelic!-a 'My Cool Website'
	}

The application name can be omitted, and the plugin will check ALL applications defined for your account.
However, this will do multiple API calls, each being a separate HTTP transaction.
Hence it may exceed the default setting of service_check_timeout in nagios.cfg

It is also desirable to keep each applications' performance data separate in PNP4Nagios.

PNP4Nagios
----------
No custome template has been created for this plugin (yet).
The default templates work well.

Other Requirements
------------------

Perl packages required by this plugin:

	LWP:       libwww-perl  (deb)    or   perl-libwww-perl (rpm)
	XML::XPath libxml-xpath-perl (deb) or perl-XML-XPath   (rpm)

