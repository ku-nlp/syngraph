#!/usr/bin/env perl

# $Id$

# KNP::Resultを使ってSynGrpah解析結果を読み込むサンプルプログラム

# usage: perl knp_syn.pl -s ホテルに一番近い駅 -relation | perl read-knp-result.pl

use strict;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(utf8)';
binmode DB::OUT, ':encoding(utf8)';
use KNP;

my $knp_buf;

#open F, "<:encoding(euc-jp)", $ARGV[0] or die;
while (<>) {
#while (<F>) {
    $knp_buf .= $_;

    if (/^EOS$/) {
	my $knp_result = new KNP::Result($knp_buf);

	print $knp_result->all_dynamic, "\n";

	foreach my $tag ($knp_result->tag) {
	    for my $synnodes ($tag->synnodes) {
		print $synnodes->tagid . ' ' . $synnodes->parent . $synnodes->dpndtype . ' ' . $synnodes->midasi . ' ' . $synnodes->feature . "\n";

		for my $synnode ($synnodes->synnode) {
		    print ' ' . $synnode->tagid . ' ' . $synnode->synid . ' ' . $synnode->score . "\n";
		}
	    }
	}
	$knp_buf = '';
    }
}
