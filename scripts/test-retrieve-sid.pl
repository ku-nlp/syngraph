#!/usr/bin/env perl

# usage: perl -I../perl test-retrieve-sid.pl -isa 生産

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
use Encode;
use Getopt::Long;
use SynGraph;

my %opt; GetOptions(\%opt, 'dbdir=s', 'isa');

my $word0 = decode('utf-8', $ARGV[0]);

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
$regnode_option->{isa} = 1 if $opt{isa};

my $result = new KNP::Result($sgh->OutputSynFormat($knp_result0, $regnode_option));

my $synids = $sgh->RetrieveSids($result);

for my $type ('syn', 'isa') {
    next if !$opt{isa} && $type eq 'isa';
    if (defined $synids->{$type}) {
	print "$type";
	print ' ', join(',', @{$synids->{$type}}), "\n";
    }
}
