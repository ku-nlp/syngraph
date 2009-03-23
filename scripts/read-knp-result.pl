#!/usr/bin/env perl

# $Id$

# KNP::Resultを使ってSynGrpah解析結果を読み込むサンプルプログラム

# usage: perl knp_syn.pl -s ホテルに一番近い駅 -relation | perl read-knp-result.pl

use strict;
use encoding 'euc-jp';
use KNP;
use Getopt::Long;
use SynGraph;

my %opt;
GetOptions(\%opt, 'count_synnode');

my $syngraph = new SynGraph;

my $knp_buf;

while (<>) {
    $knp_buf .= $_;

    if (/^EOS$/) {
	my $knp_result = new KNP::Result($knp_buf);

	if ($opt{count_synnode}) {
	    my ($tagnum, $synnode_num) = $syngraph->CountSynNodeNum($knp_result);
	    print "tagnum: $tagnum\n";
	    print "synnodenum: $synnode_num\n";
	}
	else {
	    print $knp_result->all_dynamic, "\n";

	    foreach my $tag ($knp_result->tag) {
		for my $synnodes ($tag->synnodes) {
		    print $synnodes->tagid . ' ' . $synnodes->parent . $synnodes->dpndtype . ' ' . $synnodes->midasi . ' ' . $synnodes->feature . "\n";

		    for my $synnode ($synnodes->synnode) {
			print ' ' . $synnode->tagid . ' ' . $synnode->synid . ' ' . $synnode->score . "\n";
		    }
		}
	    }
	}

	$knp_buf = '';
    }
}
