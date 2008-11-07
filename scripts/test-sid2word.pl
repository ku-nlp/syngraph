#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl test-sid2word.pl 

use encoding 'utf8';
use strict;
use SynGraph;
use Dumpvalue;
use Getopt::Long;

my %opt;
GetOptions(\%opt, 'synid=s', 'constructor');

$opt{synid} = 's1303:ごたつく/ごたつく' unless $opt{synid};

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

Dumpvalue->new->dumpValue(\@words);

unless ($opt{constructor}) {
    untie %syndb;
}
