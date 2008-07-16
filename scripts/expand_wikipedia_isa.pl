#!/usr/bin/env perl

# Wikipediaから抽出した上位語を同義関係を使って拡張する

# usage: perl expand_wikipedia_isa.pl -synonymfile ../dic_change/synonym_web_news.txt < ../dic/wikipedia/isa.txt

use strict;
use encoding 'euc-jp';
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'synonymfile=s');

my (%line2synonyms, %synonyms);
open(F, '<:encoding(euc-jp)', $opt{synonymfile}) or die;

my $line_num = 0;
while (<F>) {
    chomp;

    my @words = split;
    $line2synonyms{$line_num} = \@words;

    for my $word (@words) {
	push @{$synonyms{$word}}, $line_num;
    }
    $line_num++;
}

close F;

while (<>) {
    chomp;

    my ($hyponym, $hypernym, $num) = split;

    print "$hyponym $hypernym $num\n";

    if (defined $synonyms{$hyponym}) {
	# 多義の場合はnext
	next if scalar @{$synonyms{$hyponym}} > 1;

	for my $new_hyponym (@{$line2synonyms{$synonyms{$hyponym}[0]}}) {
	    next if $new_hyponym eq $hyponym;
	    print "$new_hyponym $hypernym $num\n";
	}
    }
}
