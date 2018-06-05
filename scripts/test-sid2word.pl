#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl test-sid2word.pl 

use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
use strict;
use SynGraph;
use Dumpvalue;
use Getopt::Long;
use Encode;

my %opt;
GetOptions(\%opt, 'synid=s', 'constructor', 'dbdir=s', 'orig', 'debug');

$opt{synid} = decode('utf-8', $opt{synid});

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
my $syngraph = new SynGraph($dbdir, $knp_option, $option);

my @words;
#if ($opt{constructor}) {
    @words = $syngraph->sid2word($opt{synid});
#}
#else {
#    @words = $syngraph->sid2word($opt{synid}, \%syndb);
#}

if ($opt{debug}) {
    Dumpvalue->new->dumpValue(\@words);
}

my @out;
for my $word (@words) {
    # 代表表記
    if ($opt{orig}) {
	push @out, $word->{orig};
    }
    else {
	push @out, $word->{word};
    }
}

print join(',', @out), "\n";

#unless ($opt{constructor}) {
#    untie %syndb;
#}
