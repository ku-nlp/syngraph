#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl test-sid2word.pl 

use encoding 'utf8';
use strict;
use SynGraph;
use Dumpvalue;
use Getopt::Long;

my %opt;
GetOptions(\%opt, 'synid=s');

$opt{synid} = 's1303:ごたつく/ごたつく' unless $opt{synid};

my $syngraph = new SynGraph;

my %syndb;
SynGraph::tie_cdb('../syndb/cgi/syndb.cdb', \%syndb);

my @words = $syngraph->sid2word($opt{synid}, \%syndb);
Dumpvalue->new->dumpValue(\@words);

untie %syndb;
