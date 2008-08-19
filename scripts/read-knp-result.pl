#!/usr/bin/env perl

# $Id$

# KNP::Result��Ȥä�SynGrpah���Ϸ�̤��ɤ߹��ॵ��ץ�ץ����

# usage: perl knp_syn.pl -s �ۥƥ�˰��ֶᤤ�� -relation | perl read-knp-result.pl

use strict;
use encoding 'euc-jp';
use KNP;

my $knp_buf;

while (<>) {
    $knp_buf .= $_;

    if (/^EOS$/) {
	my $knp_result = new KNP::Result($knp_buf);

	print $knp_result->all_dynamic, "\n";

	foreach my $tag ($knp_result->tag) {
	    my $syngraph = $tag->syngraph;
	    print $syngraph->tagid . ' ' . $syngraph->parent . $syngraph->dpndtype . ' ' . $syngraph->midasi . ' ' . $syngraph->feature . "\n";

	    for my $node ($syngraph->synnode) {
		print ' ' . $node->tagid . ' ' . $node->synid . ' ' . $node->score . "\n";
	    }
	}
	$knp_buf = '';
    }
}
