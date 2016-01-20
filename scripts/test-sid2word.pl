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
GetOptions(\%opt, 'syndb_cdb=s', 'synid=s', 'constructor', 'orig', 'debug');

$opt{synid} = decode('utf-8', $opt{synid});

$opt{syndb_cdb} = '../syndb/cgi/syndb.cdb' unless $opt{syndb_cdb};

my $syngraph;
# constructorでsyndb_cdbを渡すオプション
if ($opt{constructor}) {
    $syngraph = new SynGraph(undef, undef, { syndbcdb => $opt{syndb_cdb} });
}
else {
    $syngraph = new SynGraph;
}

my %syndb;
unless ($opt{constructor}) {
    SynGraph::tie_cdb($opt{syndb_cdb}, \%syndb);
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
