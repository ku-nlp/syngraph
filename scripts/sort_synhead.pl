#!/usr/local/bin/perl

# $Id$

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';
use Getopt::Long;
use SynGraph;

my %opt; GetOptions(\%opt, 'syndbdir=s');
my $sgh = new SynGraph;

# synhead_sort.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';

# 類義表現DBの読み込み
&SynGraph::retrieve_mldbm("$dir/syndata.mldbm", $sgh->{syndata});
&SynGraph::retrieve_cdb("$dir/synhead.cdb", $sgh->{synhead});


# 小さい順にソート
foreach my $node_id (keys %{$sgh->{synhead}}) {
    my @sort = sort {@{$sgh->{syndata}->{(split('%', $a))[0]}} <=> @{$sgh->{syndata}->{(split('%', $b))[0]}}} (split(/\|/, $sgh->{synhead}->{$node_id}));
    $sgh->{synheadsort}->{$node_id} = join ("|", @sort);
}

# 保存
&SynGraph::store_cdb("$dir/synhead_sort.cdb", $sgh->{synheadsort});
