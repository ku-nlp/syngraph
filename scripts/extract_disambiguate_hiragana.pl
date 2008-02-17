#!/usr/bin/env perl

# $Id$

# ContentW.dicから曖昧性のあるひらがなを抽出する

# usage: perl -I../perl extract_disambiguate_hiragana.pl -jumandicdir /home/shibata/download/juman/dic/ -makedb ../db/hiragana_disambiguate.cdb

use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';
use Getopt::Long;
use JumanLib;
use Constant;

my (%opt);
GetOptions(\%opt, 'jumandicdir=s', 'help', 'makedb=s', 'debug');

unless ( -e $opt{jumandicdir} ) {
    print STDERR "Please specify Jumandicdir!!\n";
    exit;
}

my $t;
if ($opt{makedb}) {
    require CDB_File;

    $t = new CDB_File ("$opt{makedb}", "$opt{makedb}.$$") or die "$!";
}

my %midasi2repname;

# Jumanの辞書の読み込み
for my $dicfile (glob("$opt{jumandicdir}/*.dic")) {
    open DIC, "<:encoding(euc-jp)", $dicfile || die;
    print STDERR "OK $dicfile\n" if $opt{debug};

    while (<DIC>) {

	my ($top_midashi_dic, $midashi_dic, $yomi_dic, $hinshi_dic, $hinshi_bunrui_dic, $conj_dic, $imis_dic) = read_juman($_);
	next unless $imis_dic; # 意味情報がないならスキップ

	my $repname;
	if ($imis_dic =~ /代表表記:(\S+?) ?$/) {
	    $repname = $1;
	    next unless $repname =~ /^\p{Han}+\//;
	}
	else {
	    next;
	}

	my @midasi = split(/ /, $midashi_dic);

	foreach my $midasi (@midasi) {
	    $midasi =~ s/:.+//;
	    if ($midasi =~ /^\p{Hiragana}+$/) {
		$midasi2repname{$midasi}{$repname} = 1;
	    }
	}
    }

    close DIC;
}

foreach my $midasi (sort keys %midasi2repname) {
    # 2つ以上の曖昧性
    if (scalar keys %{$midasi2repname{$midasi}} > 1) {
	my $disambiguate = join('?', keys %{$midasi2repname{$midasi}});
	if ($opt{makedb}) {
	    $t->insert($midasi, $disambiguate);
	}
	else {
	    print "$midasi $disambiguate\n";
	}
    }
}

$t->finish if $opt{makedb};