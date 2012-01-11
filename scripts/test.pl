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
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

my %opt; GetOptions(\%opt, 'debug', 'match_print', 'no_case', 'postprocess', 'store_fstring','relation', 'antonym', 'hypocut_attachnode=s', 'coordinate_matching', 'hypocut_matching=s', 'orchid', 'relation_recursive');

my ($zenbun, $query);
if ($ARGV[0] && $ARGV[1]) {
    $zenbun = decode('utf-8', $ARGV[0]);
    $query = decode('utf-8', $ARGV[1]);
}

# my ($zenbun, $query) = ('一番近い駅', '最寄りの駅');
# my ($zenbun, $query) = ('彼に向かわせる', '彼が向かう');

my $option;
$option->{debug} = 1 if $opt{debug};
$option->{orchid} = 1 if $opt{orchid};
$option->{no_case} = 1 if $opt{no_case};
$option->{postprocess} = 1 if $opt{postprocess};
$option->{store_fstring} = 1 if $opt{store_fstring};
$option->{relation} = 1 if $opt{relation};
$option->{relation_recursive} = 1 if $opt{relation_recursive};
$option->{antonym} = 1 if $opt{antonym};
$option->{hypocut_attachnode} = $opt{hypocut_attachnode} if $opt{hypocut_attachnode};
$option->{coordinate_matching} = 1 if $opt{coordinate_matching};
$option->{hypocut_matching} = $opt{hypocut_matching} if $opt{hypocut_matching};

my $calcsim = new CalcSimWithSynGraph($option);
my ($result, $newnode) = $calcsim->Match(1, $zenbun, $query, $option);

if ($result == 0) {
    print "unmatch\n";
}
else {
    printf "類似度:%1.2f\n",$newnode->{score};

    if ($opt{match_print}){
	printf "マッチング:\n";
	foreach my $qmatch (keys %{$newnode->{matchbp}}){ 
	    printf "$qmatch <=> $newnode->{matchbp}->{$qmatch}->{match_node}   <$newnode->{matchbp}->{$qmatch}->{match_type}>\n";
	}
    }
}
