#!/usr/bin/perl

=head1 NAME

logstash-delete-index - A script to delete older logstash indices from elasticsearch.

=head1 SYNOPSIS

    logstash-delete-index [ OPTIONS ]

    logstash-delete-index --help

=head1 REPORTING BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 POWERED BY

     _    __ _____ _____ __  __ __ __   __
    | |__|  |     |     |  \|  |__|\  \/  /
    |  . |  |  |  |  |  |      |  | >    <
    |____|__|_____|_____|__|\__|__|/__/\__\

=head1 COPYRIGHT

Copyright (C) 2013 by Jonny Schulz. All rights reserved.

=cut

package ES::Index;

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request;

sub delete {
    my ($class, %opts) = @_;
    my $self = bless \%opts, $class;

    $self->{json} = JSON->new->utf8;
    $self->{lwp}  = LWP::UserAgent->new();

    if ($self->{auth}) {
        $self->{auth} = [ split(/:/, $self->{auth}, 2) ];
    }

    my @time = (localtime(time - ($opts{delete} * 86400)))[3,4,5];
    my $time = sprintf("%04d%02d%02d", $time[2] + 1900, $time[1] + 1, $time[0]);
    my $uri  = "$opts{proto}://$opts{host}";
    my $res  = $self->request(GET => "$uri/_status") or die $self->errstr;

    if (!exists $res->{indices} || !scalar keys %{$res->{indices}}) {
        print "no indices found\n";
        exit 0;
    }

    foreach my $index (keys %{$res->{indices}}) {
        if ($index =~ /^logstash\-(\d\d\d\d)\.(\d\d)\.(\d\d)/) {
            my $itime = "$1$2$3";

            if ($itime >= $time) {
                next;
            }

            if (!$self->{run}) {
                print "delete index '$index' (run=0)\n";
                next;
            }

            my $del = $self->request(DELETE => "$uri/$index")
                or warn $self->errstr;

            my $status = $del->{ok} eq "true" ? "was successful" : "failed";
            print "delete index '$index' $status\n";
        } elsif (!$self->{run}) {
            print "skip index '$index'\n";
        }
    }
}

sub request {
    my $self = shift;
    my $req  = HTTP::Request->new(@_);
    my $data = undef;

    if ($self->{auth}) {
        $req->authorization_basic(@{ $self->{auth} });
    }

    eval {
        local $SIG{__DIE__} = sub { alarm(0) };
        local $SIG{ALRM} = sub { die "request timed out after 60 seconds" };
        alarm(60);

        my $res = $self->{lwp}->request($req);

        if (!$res->is_success) {
            return $self->errstr("request to elasticsearch failed - ".$res->status_line);
        }

        alarm(0);
        $data = $self->{json}->decode($res->content);
    };

    if ($@) {
        return $self->errstr($@);
    }

    if (!$data || ref $data ne "HASH") {
        return $self->errstr("invalid data structure received from elasticsearch");
    }

    return $data;
}

sub errstr {
    my ($self, $errstr) = @_;
    $self->{errstr} = $errstr;
    return undef;
}

package main;

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);

my $progname = do { $0 =~ m!([^/]+)\z!; $1 };
my $host     = "127.0.0.1:9200";
my $proto    = "http";
my $auth     = undef;
my $delete   = undef;
my $run      = undef;
my $help     = undef;
my $version  = undef;

GetOptions(
    "H|host=s"   => \$host,
    "p|proto=s"  => \$proto,
    "a|auth=s"   => \$auth,
    "d|delete=s" => \$delete,
    "r|run"      => \$run,
    "h|help"     => \$help,
) or exit 1;

if ($help) {
    print "\nUsage: $progname [ OPTIONS ]\n\n";
    print "Options:\n\n";
    print "-H, --host <host:port>\n";
    print "    The host and port name of the elasticsearch instance.\n";
    print "    Default: 127.0.0.1:9200\n";
    print "-p, --proto <http|https>\n";
    print "    Use http or https to connect to elasticsearch.\n";
    print "    Default: http\n";
    print "-a, --auth <username:password>\n";
    print "    Pass a string to auth via auth basic.\n";
    print "-d, --delete <days>\n";
    print "    Delete all indexes that are older than --delete days.\n";
    print "-r, --run\n";
    print "    This parameter must be set to really delete indices.\n";
    print "    If the parameter is not set then the indices are printed to\n";
    print "    stdout that would be deleted if the parameter --run were set.\n";
    print "-h, --help\n";
    print "    Print the help.\n";
    print "\n";
    exit 0;
}

# Simple host:port check.
if (!$host || $host !~ /^[a-zA-Z0-9\-\.\:]+:\d{0,5}\z/) {
    print "Missing or invalid value of parameter --host\n";
    exit 3;
}

if (!$delete || $delete !~ /^\d+\z/) {
    print "Missing or invalid value of parameter --delete\n";
    exit 3;
}

ES::Index->delete(
    host   => $host,
    proto  => $proto,
    auth   => $auth,
    delete => $delete,
    run    => $run,
);

exit 0;