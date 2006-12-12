#!/usr/local/bin/perl

# $Id$

use strict;
use Getopt::Long;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'syndbdir=s');
my $sgh = new SynGraph;

# synhead_sort.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';

print $dir . "\n";

# 類義表現DBの読み込み
$sgh->retrieve_syndb('../syndb/syndata.mldbm', '../syndb/synhead.mldbm', '../syndb/synparent.mldbm', '../syndb/synantonym.mldbm');

# 小さい順にソート
foreach my $node (keys %{$sgh->{synhead}}) {
    my @sort = sort {@{$sgh->{syndata}->{$a}} <=> @{$sgh->{syndata}->{$b}}} @{$sgh->{synhead}->{$node}};
    $sgh->{synhead}->{$node} = \@sort;
}

# 保存
&SynGraph::store_mldbm("$dir/synhead_sort.mldbm", $sgh->{synhead});
