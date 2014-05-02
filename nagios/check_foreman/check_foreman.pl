#!/usr/bin/perl

#############################################################################
#                                                                           #
# This script was initially developed by Infoxchange for internal use        #
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

use strict;
use LWP;
use LWP::UserAgent;
use Getopt::Std;
use JSON;
#use Data::Dumper;

my %optarg;
my $getopt_result;

my $lwp_user_agent;
my $http_request;
my $http_response;
my $url;
my $body;
my @body;

my @message;
my @perf_message;
my %message_ndx = (
	total => 0,
	changed => 1,
	out_of_sync => 2,
	failing => 3,
	other => 4
);
my $host_age_mins = 25;
my $host_changed_mins = 25;
my %num_hosts = ();
my $exit = 0;
my @exit = qw/OK: WARNING: CRITICAL: UNKNOWN:/;

my $rcs_id = '$Id$';
my $rcslog = '
	$Log$
	';

my $timeout = 10;			# Default timeout
my $host = 'localhost';		# default host header
my $host_ip = 'localhost';		# default IP
my $port = 80; 			# default port
my $user = 'nagios';		# default user
my $password = 'nagios';	# default password
my $http = 'http';
my $warn_threshold = 1;
my $crit_threshold = 4;
my $max_hosts = 5;
my $show_fqdn = 0;
my @hostgroup_incl = ();
my @hostgroup_excl = ();
my %hostgroup_id2name = ();
my %hostgroup_name2id = ();
my $ssl_verify_hostname = 1;

$getopt_result = getopts('hvFSsikH:I:p:w:c:t:l:a:N:g:G:m:o:', \%optarg) ;

sub HELP_MESSAGE() {
	print <<EOF;
Usage:
	$0 [-v] [-H hostname] [-I ip_address] [-p port] [-S] [-k] [-F] [-t time_out] [-l user] [-a password] [-w num1] [-c num2] [-o mins] [-m mins] [-g hostgroup,...] [-G hostgroup,...]

	-H  ... Hostname and Host: header (default: $host)
	-I  ... IP address (default: none)
	-p  ... Port number (default: ${port})
	-S  ... Use SSL connection
	-k  ... Disable SSL certificate checks (insecure - see below)
	-v  ... verbose messages to STDERR for testing
	-s  ... summary mode - don't print failing hosts, just report the numbers
	-N  ... maximum number of hosts to list per category (deafult: $max_hosts )
	-F  ... show fqdn (full hostnames with domain) default: show short hostname only
	-t  ... Seconds before connection times out. (default: $timeout)
	-l  ... user for authentication (default: $user)
	-a  ... password for authentication (default: embedded in script)
	-g  ... Include only hostgroups listed
	-G  ... exclude hostgroups listed
	-o  ... show hosts with no reports in the last 'mins' interval as out-of-date (default: $host_age_mins)
	-m  ... show hosts which have been modified in the last 'mins' interval as changed (default: $host_changed_mins)

	-w  ... warning if num1 hosts (or more) are failing
	-c  ... critical if num2 hosts (or more)

Notes:
	theforman REQUIRES HTTP Basic Authentication, and does not send back the appropriate Authenticate header
	This prevents the API being accessed from most browsers and other clients, unless the username:password is specifed in the URL

	SSL Certificate checks can use a custom CA file, by setting the environment variable PERL_LWP_SSL_CA_FILE or HTTPS_CA_FILE
	See man LWP::UserAgent for more information

Examples:

EOF
}

# Any invalid options?
if ( $getopt_result == 0 ) {
	HELP_MESSAGE();
	exit 1;
}
if ( $optarg{h} ) {
	HELP_MESSAGE();
	exit 0;
}
sub VERSION_MESSAGE() {
	print "$^X\n$rcs_id\n";
}

sub printv($) {
	if ( $optarg{v} ) {
		chomp( $_[-1] );
		print STDERR @_;
		print STDERR "\n";
	}
}

if ( defined($optarg{o}) ) {
	$host_age_mins = $optarg{o};
}

if ( defined($optarg{m}) ) {
	$host_changed_mins = $optarg{m};
}


my %uri = (
	dashboard => '/api/dashboard',
	hostgroups => '/api/hostgroups?per_page=10000',
	total => '/api/hosts?per_page=10000',
	changed => '/api/hosts?per_page=10000&search=last_report+>+"' . $host_changed_mins . '+minutes+ago"+and+(status.applied+>+0+or+status.restarted+>+0)+and+(status.failed+%3D+0)',
	out_of_sync => '/api/hosts?per_page=10000&search=%28+last_report+<+"' . $host_age_mins . '+minutes+ago"+or+not+has+last_report+%29+and+status.enabled+%3D+true',
	failing => '/api/hosts?per_page=10000&search=last_report+%3E+%22'. $host_age_mins . '+minutes+ago%22+and+%28status.failed+%3E+0+or+status.failed_restarts+%3E+0%29+and+status.enabled+%3D+true',
);

if ( defined($optarg{t}) ) {
	$timeout = $optarg{t};
}

# Is port number numeric?
if ( defined($optarg{p}) ) {
	$port = $optarg{p};
	if ( $port !~ /^[0-9][0-9]*$/ ) {
		print STDERR <<EOF;
		Port must be a decimal number, eg "-p 8080"
EOF
	exit 1;
	}
}

if ( defined($optarg{H}) ) {
	$host = $optarg{H};
	$host_ip = $host;
}

if ( defined($optarg{I}) ) {
	$host_ip = $optarg{I};
	if ( ! defined($optarg{H}) ) {
		$host = $host_ip;
	}
}

if ( defined($optarg{l}) ) {
	$user = $optarg{l};
}

if ( defined($optarg{a}) ) {
	$password = $optarg{a};
}

if ( defined($optarg{S}) ) {
	$http = 'https';
	if ( ! defined($optarg{p} ) ) {
		$port=443;
	}
}
if ( defined($optarg{k}) ) {
	$ssl_verify_hostname = 0;
}
if ( defined($optarg{F}) ) {
	$show_fqdn = 1;
}

if ( defined($optarg{N}) ) {
	$max_hosts = $optarg{N};
}

if ( defined($optarg{s}) ) {
	$max_hosts = 0;
}

if ( defined($optarg{c}) ) {
	$crit_threshold = $optarg{c};
}

if ( defined($optarg{w}) ) {
	$warn_threshold = $optarg{w};
}

if ( defined($optarg{g}) ) {
	@hostgroup_incl = split(/[, ]+/,$optarg{g});
}

if ( defined($optarg{G}) ) {
	@hostgroup_excl = split(/[, ]+/,$optarg{G});
}

# Don't need this because we are inserting the header directly using LWP::Authen::Basic
# The line below breaks the Nagios embedded perl, anyway
#*LWP::UserAgent::get_basic_credentials = sub {
#        return ( $user, $password );
#};

printv "Connecting to $host:${port}\n";

$lwp_user_agent = LWP::UserAgent->new;
$lwp_user_agent->timeout($timeout);
$lwp_user_agent->ssl_opts( verify_hostname => $ssl_verify_hostname );
if ( $port == 80 || $port == 443 || $port eq "" ) {
	$lwp_user_agent->default_header('Host' => $host);
} else {
	$lwp_user_agent->default_header('Host' => "$host:$port");
}

#----------------------------------------------------------------------------
# Get dashboard summary
$url = "$http://${host_ip}:${port}$uri{dashboard}";
$http_request = HTTP::Request->new(GET => $url);

# This hack is necessary, because The Foreman web server does not return a header like this:
# WWW-Authenticate: Basic realm="Some Realm"
#
# LPW uses this as a trigger set the correct authentication method, in this case Basic Authentication
# We work around it by putting the Basic Authentication credentials in the initial request.
use LWP::Authen::Basic;
$lwp_user_agent->default_header( 'Authorization' => LWP::Authen::Basic::auth_header("",$user,$password) ) ;

printv "--------------- GET $url";
printv $lwp_user_agent->default_headers->as_string . $http_request->headers_as_string;
#printv $lwp_user_agent->default_headers->as_string;

$http_response = $lwp_user_agent->request($http_request);
printv "---------------\n" . $http_response->protocol . " " . $http_response->status_line;
printv $http_response->headers_as_string;

my %dashboard = ();
if ($http_response->is_success) {
	printv "Content has " . length($http_response->content) . " bytes \n";
	$body = $http_response->content;
	printv("$body");
	my @json_array = decode_json $body;
	%dashboard = %{$json_array[0]};
	#printv Dumper(\%dashboard);
	#printv "Total=". $dashboard{'total_hosts'} . "\n";
	$num_hosts{total} = $dashboard{'total_hosts'};
	$num_hosts{failing} = $dashboard{'bad_hosts_enabled'};
	$num_hosts{out_of_sync} = $dashboard{'out_of_sync_hosts_enabled'};
	$num_hosts{reports_missing} = $dashboard{'reports_missing'};
	$num_hosts{changed} = $dashboard{'active_hosts_ok_enabled'};

} else {
	print "CRITICAL: $url " . $http_response->protocol . " " . $http_response->status_line ."\n";
	exit 2;
}
#----------------------------------------------------------------------------
# Get the mapping of hostgroup names to id's
if ( @hostgroup_incl >0 || @hostgroup_excl > 0 ) {
	$url = "$http://${host_ip}:${port}$uri{hostgroups}";
	$http_request = HTTP::Request->new(GET => $url);
	printv "--------------- GET $url";
	printv $lwp_user_agent->default_headers->as_string . $http_request->headers_as_string;
	$http_response = $lwp_user_agent->request($http_request);
	printv "---------------\n" . $http_response->protocol . " " . $http_response->status_line;
	if ($http_response->is_success) {
		$body = $http_response->content;
		printv("$body");
		my $json_array = decode_json $body;
		#printv Dumper(\@json_array);
		my @hostgroups = @{$json_array};
		#printv Dumper(@hostgroups);
		my $hostgroup;
		foreach $hostgroup ( @hostgroups ) {
			#print Dumper($hostgroup);
			my $name;
			my $id;
			$name = $hostgroup->{hostgroup}{name};
			$id = $hostgroup->{hostgroup}{id};
			$hostgroup_id2name{$id} = $name;
			$hostgroup_name2id{$name} = $id;
			#printv "hostgroup=$name, id=$id\n";
		}
	}
	my $hostgroup;
	foreach $hostgroup ( @hostgroup_incl, @hostgroup_excl ) {
		if ( ! defined($hostgroup_name2id{$hostgroup} ) ) {
			$message[$message_ndx{other}] .= "hostgroup $hostgroup does not exist";
			$exit |= 1;
		}
	}
}

#----------------------------------------------------------------------------
# Get list of hosts for each state we are interested in
sub get_hosts_in_state($) {
	my $state = $_[0];
	my @result = ();
	printv "$state";
	$url = "$http://${host_ip}:${port}$uri{$state}";
	printv "  $url\n";

	# use the existing LWP::UserAgent since it already has the basic credentials
	my $http_request = HTTP::Request->new(GET => $url);
	printv "--------------- GET $url";
	printv $lwp_user_agent->default_headers->as_string . $http_request->headers_as_string;
	#printv $lwp_user_agent->default_headers->as_string;

	my $http_response = $lwp_user_agent->request($http_request);
	printv "---------------\n" . $http_response->protocol . " " . $http_response->status_line;
	printv $http_response->headers_as_string;

	my $host_count = 0;
	if ($http_response->is_success) {
		$body = $http_response->content;
		printv("$body");
		my $json_array = decode_json $body;
		my @hosts_failed = @{$json_array};
		#print Dumper(\@hosts_failed);
		my $host;
		foreach $host ( @hosts_failed ) {
			#print Dumper($host);
			my $this_host = $host->{'host'}{'name'};
			my $this_host_id = $host->{'host'}{'hostgroup_id'};
			if ( @hostgroup_incl > 0  ) {
				if ( grep($this_host_id eq $hostgroup_name2id{$_}, @hostgroup_incl) > 0 ) {
					printv "Found $this_host in hostgroup $hostgroup_id2name{$this_host_id}\n";
				} else {
					next;
				}
			} elsif ( @hostgroup_excl > 0 && defined($this_host_id ) && grep($this_host_id eq $hostgroup_name2id{$_}, @hostgroup_excl) ) {
				next;
			}
			if ( $show_fqdn == 0 && $this_host !~ /^\./ ) {
				$this_host =~ s/\..*//;
			}
			if ($host_count == $max_hosts) {
				if ( $max_hosts > 0 ) {
					$result[$#result] .= '...';
				}
			} elsif ( $host_count < $max_hosts )  {
				push @result,$this_host;
			}

			$host_count++;
		}
	} else {
		printv "CRITICAL: $url " . $http_response->protocol . " " . $http_response->status_line ."\n";
		$exit |= 2;
		return($state,$http_response->protocol,$http_response->status_line);
	}
	return($host_count,@result);
}
#$message[$message_ndx{changed}]     = join(" ",($message[$message_ndx{changed}],get_hosts_in_state('changed')));
# This code is so we dont' do any more queries on the foreman server than we need to (eg if their is nothing going on, just use the dashboard)
my @hosts_found;
if ( @hostgroup_incl >0 || @hostgroup_excl >0 ) {
	( $num_hosts{total},@hosts_found ) = get_hosts_in_state('total');
}
$message[$message_ndx{total}]       = "Total=$num_hosts{total}";
$perf_message[$message_ndx{total}]       = "total=$num_hosts{total}";

if ( $num_hosts{changed} > 0 || defined($optarg{m}) ) {
	( $num_hosts{changed},@hosts_found ) = get_hosts_in_state('changed');
}
$message[$message_ndx{changed}]     = "Changed=$num_hosts{changed}";
$perf_message[$message_ndx{changed}]     = "changed=$num_hosts{changed}";
if ( $num_hosts{changed} > 0 && $max_hosts > 0 ) {
	$message[$message_ndx{changed}]  .= " " . join(" ",@hosts_found);
}

if ( $num_hosts{failing} > 0 ) {
	( $num_hosts{failing},@hosts_found ) = get_hosts_in_state('failing');
}
$message[$message_ndx{failing}]     = "Failing=$num_hosts{failing}";
$perf_message[$message_ndx{failing}]     = "failing=$num_hosts{failing}";
if ( $num_hosts{failing} > 0 && $max_hosts > 0 ) {
	$message[$message_ndx{failing}]  .= " " . join(" ",@hosts_found);
}

if ( $num_hosts{out_of_sync} > 0 || $num_hosts{reports_missing} > 0 || defined($optarg{o}) ) {
	( $num_hosts{out_of_sync},@hosts_found ) = get_hosts_in_state('out_of_sync');
	# We reset this, because the api-query above includes hosts-with-reports-missing
	$num_hosts{reports_missing} = 0;
}
$message[$message_ndx{out_of_sync}] = "Out_of_Sync=$num_hosts{out_of_sync}";
$perf_message[$message_ndx{out_of_sync}] = "out_of_sync=$num_hosts{out_of_sync}";
if ( $num_hosts{out_of_sync} > 0 && $max_hosts > 0 ) {
	$message[$message_ndx{out_of_sync}]  .= " " . join(" ",@hosts_found);
}

# Set exit code as per thresholds
if ( $num_hosts{failing} + $num_hosts{out_of_sync} + $num_hosts{reports_missing}  >=  $crit_threshold ) {
	$exit |= 2;
} elsif ( $num_hosts{failing} + $num_hosts{out_of_sync} + $num_hosts{reports_missing}  >=  $warn_threshold ) {
	$exit |= 1;
}

#----------------------------------------------------------------------------

if ( $exit == 3 ) {
	$exit = 2;
} elsif ( $exit > 3 || $exit < 0 ) {
	$exit = 3;
}

print "$exit[$exit] ". join(", ",@message). "|". join(" ",@perf_message) . "\n";
exit $exit;
