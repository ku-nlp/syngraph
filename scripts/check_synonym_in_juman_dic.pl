#!/usr/bin/env perl

# $Id$

# Jumanの辞書にあるエントリを削除する

# usage: perl check_synonym_in_juman_dic.pl --jumandicdir /home/shibata/download/juman/dic < www.txt

use strict;
use encoding 'euc-jp';
use Getopt::Long;
use JumanLib;
use Configure;
use CalcSimilarityByCF;
binmode STDERR, ':encoding(euc-jp)';

my (%opt);
GetOptions(\%opt, 'jumandicdir=s', 'help', 'debug');

my %MIDASI;

unless ( -e $opt{jumandicdir} ) {
    print STDERR "Please specify Jumandicdir!!\n";
    exit;
}

my $cscf = new CalcSimilarityByCF({ method => 'SimpsonJaccard' });

$cscf->TieMIDBfile($Configure::CalcsimCNMidbfile);

my $TH_DISTRIBUTIONAL_SIMILARITY = 0.3;

# Jumanの辞書の読み込み
for my $dicfile (glob("$opt{jumandicdir}/*.dic")) {
    open DIC, "<:encoding(euc-jp)", $dicfile || die;
    print STDERR "OK $dicfile\n" if $opt{debug};

    while (<DIC>) {

	my ($top_midashi_dic, $midashi_dic, $yomi_dic, $hinshi_dic, $hinshi_bunrui_dic, $conj_dic, $imis_dic) = read_juman($_);
	next unless $imis_dic; # 意味情報がないならスキップ

	my @midasi = split(/ /, $midashi_dic);

	foreach my $midasi (@midasi) {
	    $midasi =~ s/:.+//;
	    $MIDASI{$midasi} = 1;
	}
    }

    close DIC;
}


while (<>) {
    chomp;
    my ($word1, $word2) = split("\t", $_);

    # 両方登録されている -> 削除
    if (defined $MIDASI{$word1} && defined $MIDASI{$word2}) {
	print STDERR "☆$word1 $word2\n";
	next;
    }
    # 片方が登録されている -> 分布類似度が高ければ採用
    elsif (defined $MIDASI{$word1} || defined $MIDASI{$word2}) {
	my $score = $cscf->CalcSimilarity($word1, $word2, { normalized_repname => 'compound', mifilter => 1 });
	print STDERR "★$word1 $word2 $score";

	if ($score < $TH_DISTRIBUTIONAL_SIMILARITY) {
	    print STDERR " discarded\n";
	    next;
	}
	else {
	    print STDERR "\n";
	}
    }
    print "$word1\t$word2\n";
}
