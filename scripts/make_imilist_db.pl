#!/usr/bin/env perl

# $Id$

# usage: perl make_imilist_db.pl -syndb ../syndb/x86_64/syndb.cdb -outdb ../syndb/x86_64/imi_list.cdb < ../dic/wikipedia/imi-list-noun.txt

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
use Getopt::Long;
use Encode;
use CDB_File;

my (%opt);
GetOptions(\%opt, 'isa=s', 'syndb=s', 'outdb=s');

my $t;
if ($opt{outdb}) {
    $t = new CDB_File ("$opt{outdb}", "$opt{outdb}.$$") or die "$!";
}

my %syndb;
if ($opt{syndb}) {
    my $db = tie %syndb, 'CDB_File', $opt{syndb} or die;
}

my %imi_list;
# １０区:2/6 none;none;パリ市,フランス;none;首都,パリ;全２０区;フランスの首都・パリ市　（全２０区）　の「１０区」。
while (<>) {
    chomp;

    my ($entry) = split(' ', $_);

    my ($word, $sense) = split(':', $entry);
    my ($m, $n) = split('\/', $sense);

    $imi_list{$word}{$m} = '';
}

# s100498:モンテヴェルディ モンテヴェルディ:1/3[Wikipedia]
for my $key (sort keys %syndb) {
    $key = decode('utf-8', $key);
    my $value = decode('utf-8', $syndb{$key});

    for my $v (split('\|', $value)) {
	if ($v =~ /(.+?):(\d+)\/(\d+)\[(?:Wikipedia|Web)\]$/) {
	    my $word = $1;
	    my $m = $2;
	    my $n = $3;

	    if (defined $imi_list{$word} && defined $imi_list{$word}{$m}) {
		$imi_list{$word}{$m} = $key;
	    }
	}
    }
}

for my $word (sort keys %imi_list) {
    my @out;
    for my $m (sort keys %{$imi_list{$word}}) {
	if ($imi_list{$word}{$m}) {
	    push @out, "$m%$imi_list{$word}{$m}";
	}
    }
    if (scalar @out > 0) {
	my $value = join('|', @out);
	if ($opt{outdb}) {
	    $t->insert($word, $value);
	}
	else {
	    print "$word $value\n";
	}
    }
}

if ($opt{syndb}) {
    untie %syndb;
}

if ($opt{outdb}) {
    $t->finish;
}
