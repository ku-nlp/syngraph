#!/usr/bin/env perl

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';

use KNP;

my $knp = new KNP(-Option => '-tab -postprocess');

# 緩和/かんわ:1/1:1/1 程度をゆるめること。

while (<>) {
    chomp;

    my ($midasi, $definition) = split;

    my $result = $knp->parse($definition);

    for my $tag ($result->tag) {
	if ($tag->fstring =~ /<体言>/ && $tag->fstring =~ /<係:(.+)格>/) {
	    my $case = $1;
	    print &get_jiritsu($tag), " $case $midasi $definition\n";
	}
    }
}

sub get_jiritsu {
    my ($tag) = @_;

    my $string;

    for my $mrph ($tag->mrph) {
	if ($mrph->fstring =~ /<準?内容語>/) {
	    $string .= $mrph->midasi;
	}
    }
    return $string;
}
