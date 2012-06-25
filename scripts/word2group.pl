#!/usr/bin/env perl

# perl -I../perl word2group.pl | make-cdb.pl --db ../db/word2group.db

use utf8;
binmode STDOUT, ':encoding(utf-8)';
use strict;
use SynGraph;
use Encode;

my %id2word;
&SynGraph::tie_cdb('/home/shibata/work/SynGraph/syndb/cgi/syndb.cdb', \%id2word);

my %data;
# s19994:ほぐす/ほぐす -> ほぐす/ほぐす:1/1:1/2[DIC]|もつれたものをほどく[定義文]
foreach my $id (keys %id2word) {
    $id = decode('utf8', $id);
    my $string = decode('utf8', $id2word{$id});

    for my $entry (split('\|', $string)) {
#	next if $entry !~ /[(?:DIC|定義文)]/;

	if ($entry =~ /^([^:\[]+)/) {
	    $entry = $1;
	}
	push @{$data{$entry}}, $id;
    }
}

foreach my $entry (keys %data) {
#    print STDERR "$entry -> ", join('|', @{$data{$entry}}), "\n";
    print "$entry ", join('|', @{$data{$entry}}), "\n";
#    $regist_data{$entry} = join('|', @{$data{$entry}});
}
