#!/usr/bin/env perl

# KNPへのSYNGRAPH導入のテスト用プログラム

use strict;
use Dumpvalue;
use utf8;
use Encode;
use lib qw(../perl);
use CalcSimWithSynGraph;
use Getopt::Long;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'sentence=s', 'debug', 'postprocess', 'relation', 'antonym');

# my $input = '一番近い駅';
 my $input = '彼の歩き方を学ぶ';
#my $input = '彼は彼女を助ける';

my $option;
my $knp_option;
my $regnode_option;
$option->{debug} = 1 if $opt{debug};
$knp_option->{postprocess} = 1 if $opt{postprocess};
$regnode_option->{relation} = 1 if $opt{relation};
$regnode_option->{antonym} = 1 if $opt{antonym};

my $SynGraph = new SynGraph($knp_option);


# 類義表現DBをtie
$SynGraph->tie_syndb('../syndb/syndata.mldbm', '../syndb/synhead.mldbm', '../syndb/synparent.mldbm', '../syndb/synantonym.mldbm');
#$SynGraph->tie_syndb('../syndb.back/syndata.mldbm', '../syndb.back/synhead.mldbm', '../syndb.back/synparent.mldbm', '../syndb.back/synantonym.mldbm');

if ($opt{sentence}) {
    $input = decode('euc-jp', $opt{sentence});
    my $result = $SynGraph->{knp}->parse($input);
    $SynGraph->OutputSynFormat($result, $regnode_option);
#    &outputformat($result);
}
else {
    my ($sid, $knp_buf);
    while (<>) {
	$knp_buf .= $_;

	if (/^EOS$/) {
	    my $result = new KNP::Result($knp_buf);
	    $result->set_id($sid) if ($sid);
	    $SynGraph->OutputSynFormat($result, $regnode_option);
	    $knp_buf = "";
	}
	elsif (/\# S-ID:(.+) KNP:/) {
	    $sid = $1;
	    $sid =~ s/\s+/ /;
	    $sid =~ s/^\s//;
	    $sid =~ s/\s$//;
	}
    }
}

