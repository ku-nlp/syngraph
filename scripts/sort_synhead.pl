#!/usr/local/bin/perl

# $Id$

use strict;
use Getopt::Long;
use SynGraph;
use encoding 'euc-jp';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'syndbdir=s');
my $sgh = new SynGraph;

# synhead_sort.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';

# 類義表現DBの読み込み
&SynGraph::retrieve_mldbm("$dir/syndata.mldbm", $sgh->{syndata});
&SynGraph::retrieve_cdb("$dir/synhead.cdb", $sgh->{synhead});


# 小さい順にソート
foreach my $node_id (keys %{$sgh->{synhead}}) {
    my @sort = sort {@{$sgh->{syndata}->{$a}} <=> @{$sgh->{syndata}->{$b}}} (split(/\|/, $sgh->{synhead}->{$node_id}));
    $sgh->{synheadsort}->{$node_id} = join ("|", @sort);
}

# 保存
&SynGraph::store_cdb("$dir/synhead_sort.cdb", $sgh->{synheadsort});
