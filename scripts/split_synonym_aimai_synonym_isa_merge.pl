#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl split_synonym_aimai_synonym_isa_merge.pl -isa_wikipedia ../dic/wikipedia/isa.txt < ../dic_middle/synonym_aimai_synonym_isa_merge.txt

use strict;
use Getopt::Long;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';
use Dumpvalue;

my %opt; GetOptions(\%opt, 'isa_wikipedia=s', 'isa_location=s', 'isa_out=s', 'synonym_out=s', 'debug');

my @synonym;
my (%isa_wikipedia, %isa_wikipedia_hypernym_num);

&read_isa_file($opt{isa_wikipedia}) if $opt{isa_wikipedia};
&read_isa_file($opt{isa_location}) if $opt{isa_location};

# オラクル:1/5	isa	託宣
# オラクル:5/5	synonym	オラクル	Ｏｒａｃｌｅ
while (<>) {
    chomp;

    if (/.+\t(?:isa|synonym)/) {
	my ($midasi, $type, @words) = split("\t", $_);

	if ($type eq 'synonym') {
	    my $line = join("\t", ($midasi, @words));
	    push @synonym, $line;
	}
	else {
	    $isa_wikipedia{$midasi} = $words[0];
	    $isa_wikipedia_hypernym_num{$words[0]}++;
	}
    }
    else {
	push @synonym, $_;
    }
}

open (F, ">:encoding(euc-jp)", $opt{isa_out}) or die;
# 下位語数でソート
for my $word (sort { $isa_wikipedia_hypernym_num{$isa_wikipedia{$b}} <=> $isa_wikipedia_hypernym_num{$isa_wikipedia{$a}} || $isa_wikipedia{$a} cmp $isa_wikipedia{$b}} keys %isa_wikipedia) {
    print F "$word\t$isa_wikipedia{$word}\t$isa_wikipedia_hypernym_num{$isa_wikipedia{$word}}\n";
}
close F;

open (F, ">:encoding(euc-jp)", $opt{synonym_out}) or die;
for my $line (@synonym) {
    print F $line, "\n";
}
close F;

sub read_isa_file {
    my ($file) = @_;

    open (F, "<:encoding(euc-jp)", $file) or die;
    while (<F>) {
	chomp;

	my ($hyponym, $hypernym, $num) = split;

	if (!defined $isa_wikipedia_hypernym_num{$hypernym}) {
	    $isa_wikipedia_hypernym_num{$hypernym} = $num;
	}

	$isa_wikipedia{$hyponym} = $hypernym;
    }
    close F;
}
