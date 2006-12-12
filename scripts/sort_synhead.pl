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

# synhead_sort.mldbm���֤����
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';

print $dir . "\n";

# ���ɽ��DB���ɤ߹���
$sgh->retrieve_syndb('../syndb/syndata.mldbm', '../syndb/synhead.mldbm', '../syndb/synparent.mldbm', '../syndb/synantonym.mldbm');

# ��������˥�����
foreach my $node (keys %{$sgh->{synhead}}) {
    my @sort = sort {@{$sgh->{syndata}->{$a}} <=> @{$sgh->{syndata}->{$b}}} @{$sgh->{synhead}->{$node}};
    $sgh->{synhead}->{$node} = \@sort;
}

# ��¸
&SynGraph::store_mldbm("$dir/synhead_sort.mldbm", $sgh->{synhead});
