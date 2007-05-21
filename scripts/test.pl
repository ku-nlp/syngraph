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

my %opt; GetOptions(\%opt, 'debug', 'log_sg', 'match_print', 'no_case', 'postprocess', 'relation', 'antonym', 'pa_matching', 'wr_matching', 'orchid');

my ($zenbun, $query);
if ($ARGV[0] && $ARGV[1]) {
    $zenbun = decode('euc-jp', $ARGV[0]);
    $query = decode('euc-jp', $ARGV[1]);
}

# my ($zenbun, $query) = ('一番近い駅', '最寄りの駅');
# my ($zenbun, $query) = ('彼に向かわせる', '彼が向かう');

my $calcsim = new CalcSimWithSynGraph;
my $option;
$option->{debug} = 1 if $opt{debug};
$option->{orchid} = 1 if $opt{orchid};
$option->{log_sg} = 1 if $opt{log_sg};
$option->{no_case} = 1 if $opt{no_case};
$option->{postprocess} = 1 if $opt{postprocess};
$option->{relation} = 1 if $opt{relation};
$option->{antonym} = 1 if $opt{antonym};
$option->{pa_matching} = 1 if $opt{pa_matching};
$option->{wr_matching} = 1 if $opt{wr_matching};

my $result = $calcsim->Match(1, $zenbun, $query, $option);

if ($result eq 'unmatch') {
    print "unmatch\n";
}
else {
    printf "類似度:%1.2f\n",$result->{CALC}->{score};

    if ($opt{match_print}){
	printf "マッチング:\n";
	foreach my $qmatch (keys %{$result->{matchbp}}){ 
	    printf "$qmatch <=> $result->{matchbp}->{$qmatch}->{match_node}   <$result->{matchbp}->{$qmatch}->{match_type}>\n";
	}
    }
}
