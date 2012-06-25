#!/usr/bin/env perl

# $Id$

# 上位語抽出のパターンを見つけるスクリプト

use strict;
use encoding 'euc-jp';
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'countth=i');

my %data;
# 京成津田沼駅 駅/えき 0.500
while (<>) {
    chomp;

    my ($hyponym, $hypernym, $similarity) = split;

    $data{$hypernym}{similarity} += $similarity;
    $data{$hypernym}{count}++;
}

# 平均類似度を算出
foreach my $hypernym (keys %data) {
    $data{$hypernym}{average_similarity} = $data{$hypernym}{similarity} / $data{$hypernym}{count};
}

foreach my $hypernym (sort {$data{$a}{average_similarity} <=> $data{$b}{average_similarity}} keys %data) {
    next if defined $opt{countth} && $data{$hypernym}{count} <= $opt{countth};

    printf "%s %.4f %d\n", $hypernym, $data{$hypernym}{average_similarity}, $data{$hypernym}{count};
}
