#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl test-retrieve-sid.pl -relation 生産する

use strict;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
use Encode;
use Getopt::Long;
use SynGraph;

my %opt; GetOptions(\%opt, 'dbdir=s', 'relation');

my $word0 = decode('euc-jp', $ARGV[0]);

my $dbdir;
if ($opt{dbdir}) {
    $dbdir = $opt{dbdir};
}
else {
    my $uname = `uname -m`;
    chomp $uname;
    $dbdir = "../syndb/$uname";
}

my ($knp_option, $option);
$knp_option->{no_case} = 1;
my $sgh = new SynGraph($dbdir, $knp_option, $option);

my $knp_result0 = $sgh->{knp}->parse($word0);

my $regnode_option;
$regnode_option->{relation} = 1 if $opt{relation};

my $result = new KNP::Result($sgh->OutputSynFormat($knp_result0, $regnode_option));

my $synids = $sgh->RetrieveSids($result);

for my $type ('syn', 'isa') {
    print "$type\n";
    if (defined $synids->{$type}) {
	print ' ', join(',', @{$synids->{$type}}), "\n";
    }
}
