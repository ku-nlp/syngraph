#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl test-sid2word.pl 

use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
use strict;
use SynGraph;
use Dumpvalue;
use Getopt::Long;
use Encode;

my %opt;
GetOptions(\%opt, 'synid=s', 'constructor', 'orig', 'debug');

$opt{synid} = decode('euc-jp', $opt{synid});

my $syndb_cdb = '../syndb/cgi/syndb.cdb';

my $syngraph;
# constructorでsyndb_cdbを渡すオプション
if ($opt{constructor}) {
    $syngraph = new SynGraph(undef, undef, { syndbcdb => $syndb_cdb });
}
else {
    $syngraph = new SynGraph;
}

my %syndb;
unless ($opt{constructor}) {
    SynGraph::tie_cdb($syndb_cdb, \%syndb);
}

my @words;
if ($opt{constructor}) {
    @words = $syngraph->sid2word($opt{synid});
}
else {
    @words = $syngraph->sid2word($opt{synid}, \%syndb);
}

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

unless ($opt{constructor}) {
    untie %syndb;
}
