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

my %opt; GetOptions(\%opt, 'debug', 'postprocess', 'relation', 'antonym');

# my $sentence = '一番近い駅';
 my $sentence = '彼の歩き方を学ぶ';
#my $sentence = '彼は彼女を助ける';
if ($ARGV[0]) {
    $sentence = decode('euc-jp', $ARGV[0]);
}

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

# SynGraphを作成
my $syngraph = {};
$SynGraph->make_sg($sentence, $syngraph, 1, $regnode_option);
Dumpvalue->new->dumpValue($syngraph) if ($option->{debug});

# SynGraphを出力
$SynGraph->fomat_syngraph($syngraph->{1});
