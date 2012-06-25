#!/usr/bin/env perl

# $Id$

# ��̸���ФΥѥ�����򸫤Ĥ��륹����ץ�

use strict;
use encoding 'euc-jp';
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'countth=i');

my %data;
# �������ľ±� ��/���� 0.500
while (<>) {
    chomp;

    my ($hyponym, $hypernym, $similarity) = split;

    $data{$hypernym}{similarity} += $similarity;
    $data{$hypernym}{count}++;
}

# ʿ������٤򻻽�
foreach my $hypernym (keys %data) {
    $data{$hypernym}{average_similarity} = $data{$hypernym}{similarity} / $data{$hypernym}{count};
}

foreach my $hypernym (sort {$data{$a}{average_similarity} <=> $data{$b}{average_similarity}} keys %data) {
    next if defined $opt{countth} && $data{$hypernym}{count} <= $opt{countth};

    printf "%s %.4f %d\n", $hypernym, $data{$hypernym}{average_similarity}, $data{$hypernym}{count};
}
