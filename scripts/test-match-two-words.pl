#!/usr/bin/env perl

# $Id$

# 二つの表現の同義・上位下位関係を判定するテストプログラム

use strict;
use utf8;
use SynGraph;
use KNP;
use Getopt::Long;
use Encode;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'dbdir=s', 'relation');

my $word0 = decode('euc-jp', $ARGV[0]);
my $word1 = decode('euc-jp', $ARGV[1]);

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
my $knp_result1 = $sgh->{knp}->parse($word1);

my $regnode_option;
$regnode_option->{relation} = 1 if $opt{relation};

my $result0 = new KNP::Result($sgh->OutputSynFormat($knp_result0, $regnode_option));
my $result1 = new KNP::Result($sgh->OutputSynFormat($knp_result1, $regnode_option));

my ($match_type, $parent) = $sgh->MatchingTwoWords($result0, $result1);
if ($match_type eq 'syn') {
    print $match_type, "\n";
}
elsif ($match_type eq 'isa') {
    print "$match_type (parent=$parent)\n";
}
else {
    print "no_match\n";
}
