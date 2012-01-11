#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';
use Encode;
use SynGraph;
use Getopt::Long;

use Configure;

my (%opt);
GetOptions(\%opt);

my $edit_db = $Configure::SynGraphBaseDir . '/db/synonym_web_key2status.db';

my %KEY2STATUS;
&SynGraph::tie_mldbm($edit_db, \%KEY2STATUS);

my %DEL;

for my $line (keys %KEY2STATUS) {
    if ($KEY2STATUS{$line}{status} eq 'nouse') {
	$DEL{$KEY2STATUS{$line}{strings}[0]}{$KEY2STATUS{$line}{strings}[1]} = 1;
    }
}

while (<>) {
    chomp;

    my ($word1, $word2) = split;

    if (defined $DEL{$word1}{$word2} || $DEL{$word2}{$word1}) {
	next;
    }
    else {
	print $_, "\n";
    }
}
