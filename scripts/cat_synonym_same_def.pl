#!/usr/bin/env perl

# 辞書からの同義表現リストをformatをそろえてつなげるスクリプト

use strict;
use Getopt::Long;
use Dumpvalue;
use KNP;
use Constant;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'synonym_dic=s', 'same_definition=s', 'synonym_filter_log=s');

my $knp = new KNP( -Option => '-tab -dpnd',
		   -JumanCommand => $Constant::JumanCommand,
		   -JumanRcfile => $Constant::JumanRcfile);

open(SYN, '<:encoding(euc-jp)', $opt{synonym_dic}) or die;
while (<SYN>) {
    print $_;
}
close(SYN);

my %discarded;
open(FILTERLOG, '<:encoding(euc-jp)', $opt{synonym_filter_log}) or die;
while (<FILTERLOG>) {
    next unless /discarded$/;

    s/^[★☆]//;

    my ($midasi, $synonym) = split;

    $discarded{$midasi}{$synonym} = 1;
}
close(FILTERLOG);

my ($def);
open(SDEF, '<:encoding(euc-jp)', $opt{same_definition}) or die;
while (<SDEF>) {
    next if $_ eq "\n";
    if (/^★(.+?)$/) {
	$def = $1;
	$def =~ s/。$//;
	next;
    }

    my @synonyms = split;

    # 分布類似度でフィルタリングされた同義語は同義グループに入れないようにする
    # まず、$defが一形態素であるかどうかチェック(一形態素の場合しかフィルタリングされない)
    my $result = $knp->parse($def);
    if (scalar ($result->mrph) == 1) {
	my $repname = ($result->mrph)[0]->repname;
	my @output_synonyms;
	foreach my $synonym (@synonyms) {
	    if (defined $discarded{$synonym}{$repname}) {
		print STDERR "★$synonym $repname $def\n";
		next;
	    }
	    push @output_synonyms, $synonym;
	}

	if (scalar @output_synonyms > 1) {
	    print join (' ', @output_synonyms), "\n";
	}
    }
    # 一形態素ではないので、そのまま出力
    else {
	print join (' ', @synonyms), "\n";
    }
}
close(SDEF);
