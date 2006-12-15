#!/usr/bin/env perl

# $Id$

# 類似度計算のテスト用プログラム

use strict;
use Dumpvalue;
use utf8;
use lib qw(../perl);
use CalcSimWithSynGraph;
use Getopt::Long;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'debug', 'match_print', 'case', 'postprocess', 'relation', 'antonym');

# my $zenbun = <STDIN>;
# chomp $zenbun;
# my $query = <STDIN>;
# chomp $query;

# my ($zenbun, $query) = ('一番近い駅', '最寄りの駅');

my $calcsim = new CalcSimWithSynGraph;
my $option;
$option->{debug} = 1 if $opt{debug};
$option->{case} = 1 if $opt{case};
$option->{postprocess} = 1 if $opt{postprocess};
$option->{relation} = 1 if $opt{relation};
$option->{antonym} = 1 if $opt{antonym};

my $result = $calcsim->Match(1, $zenbun, $query, $option);

printf "類似度:%1.2f\n",$result->{score};
if ($opt{match_print}){
    printf "マッチング:\n";
    foreach my $qmatch (keys %{$result->{matchbp}}){ 
	printf "$qmatch <=> $result->{matchbp}->{$qmatch}->{match_node}   <$result->{matchbp}->{$qmatch}->{match_type}>\n";
    }
}
