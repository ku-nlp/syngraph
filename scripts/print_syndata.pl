#!/usr/bin/env perl

# $Id$

# syndataをprintするスクリプト

# usage: perl -I../perl print_syndata.pl ../syndb/i686/syndata.mldbm

use strict;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
use Getopt::Long;
use Storable qw(nstore retrieve);

my (%opt);
GetOptions(\%opt, 'storable_db=s', 'read_storable_db=s', 'dbname=s');

my $syndata_mldbm = $ARGV[0];

my %db;
if ($opt{storable_db}) {
    &SynGraph::retrieve_mldbm($syndata_mldbm, \%db);

    nstore(\%db, $opt{storable_db});
}
elsif ($opt{read_storable_db}) {
    my $syndata = retrieve($opt{read_storable_db});

    &SynGraph::store_mldbm($opt{dbname}, $syndata);
}
else {
    &SynGraph::tie_mldbm($syndata_mldbm, \%db);

# 出力例

# s10000:オープンキャンパス,オープンキャンパス
#  オープン/おーぷん|オープンだ/おーぷんだ|s1703:オープン/おーぷん|s35492:オープン/おーぷん
#  キャンパス/きゃんぱす|s31654:キャンパス/きゃんぱす

    foreach my $key ( sort { $a cmp $b } keys %db) {
	print $key, "\n";

	# 基本句
	foreach my $bp (@{$db{$key}}) {
	    my @ids;

	    # 基本ノードとSynノード
	    foreach my $node (@{$bp->{nodes}}) {
		push @ids, $node->{id};
	    }
	    print ' ', join('|', @ids), "\n";
	}
    }
}
