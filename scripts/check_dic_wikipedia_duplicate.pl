#!/usr/bin/env perl

# $Id$

# Wikipediaから得られた類義表現のうち、国語辞典からも抽出されるものを削除

# usage: perl check_dic_wikipedia_duplicate.pl -dic ../dic_change/isa.txt -wikipedia ../dic/wikipedia/isa.txt > ../dic_change/isa-wikipedia.txt 2> ../dic_change/isa-wikipedia.log

use strict;
use Getopt::Long;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';
use KNP;
use Constant;

my %opt;
GetOptions(\%opt, 'dic=s', 'wikipedia=s');

my $LENGTH_MAX = 10;

my $knp = new KNP( -Option => '-tab -dpnd',
		   -JumanCommand => $Constant::JumanCommand,
		   -JumanRcfile => $Constant::JumanRcfile);

my %DIC;

# 辞書データの読み込み
open(DIC, '<:encoding(euc-jp)', $opt{dic}) or die;
while (<DIC>) {
    chomp;

    # 息遣い/いきづかい:1/1:1/1 様子/ようす 823
    my ($hyponym, $hypernym, $num) = split;

    my ($word, $id) = split (':', $hyponym, 2);

    $DIC{$word}{$id} = $hypernym;
}
close DIC;

# Wikipediaデータの読み込み
open(W, '<:encoding(euc-jp)', $opt{wikipedia}) or die;
while (<W>) {
    chomp;

    # アンパサンド 記号/きごう
    my ($hyponym, $hypernym, $num) = split("\t", $_);

    # 長すぎる見出しはskip
    if (length $hyponym <= $LENGTH_MAX) { 
	my $result = $knp->parse($hyponym);

	if ($result && scalar ($result->mrph) == 1) {
	    my $repname = ($result->tag)[0]->repname;

	    if (defined $DIC{$repname}) {
		my @dic;
		foreach my $id (keys %{$DIC{$repname}}) {
		    push @dic, "$id-$DIC{$repname}{$id}";
		}

		print STDERR "$repname DIC: ", join(' ', @dic), " Wikipedia: $hypernym ($hyponym)\n";
		next;
	    }
	}
    }

    print "$hyponym\t$hypernym\t$num\n";
}
close W;
