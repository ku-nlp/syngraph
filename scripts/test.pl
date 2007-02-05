#!/usr/bin/env perl

# $Id$

# 類似度計算のテスト用プログラム

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

my %opt; GetOptions(\%opt, 'debug', 'match_print', 'case', 'postprocess', 'relation', 'antonym', 'jyutugokou_kaisyou', 'MT_ver');

# my $zenbun = <STDIN>;
# chomp $zenbun;
# my $query = <STDIN>;
# chomp $query;

 my ($zenbun, $query) = ('一番近い駅', '最寄りの駅');
# my ($zenbun, $query) = ('最寄り駅', '一番近い駅');

if ($ARGV[0] && $ARGV[1]) {
    $zenbun = decode('euc-jp', $ARGV[0]);
    $query = decode('euc-jp', $ARGV[1]);
}

my $calcsim = new CalcSimWithSynGraph;
my $option;
$option->{debug} = 1 if $opt{debug};
$option->{case} = 1 if $opt{case};
$option->{postprocess} = 1 if $opt{postprocess};
$option->{relation} = 1 if $opt{relation};
$option->{antonym} = 1 if $opt{antonym};
$option->{jyutugokou_kaisyou} = 1 if $opt{jyutugokou_kaisyou};
$option->{MT_ver} = 1 if $opt{MT_ver};

my $result = $calcsim->Match(1, $zenbun, $query, $option);

if ($result eq 'unmatch') {
    print "unmatch\n";
}
else {
    if (!$opt{MT_ver}){
	printf "類似度:%1.2f\n",$result->{score};
    }
    else {
	printf "類似度:%1.2f\n",$result->{CALC}->{score};
    }

    if ($opt{match_print}){
	printf "マッチング:\n";
	foreach my $qmatch (keys %{$result->{matchbp}}){ 
	    printf "$qmatch <=> $result->{matchbp}->{$qmatch}->{match_node}   <$result->{matchbp}->{$qmatch}->{match_type}>\n";
	}
    }
}
