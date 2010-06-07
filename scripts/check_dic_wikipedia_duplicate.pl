#!/usr/bin/env perl

# $Id$

# Wikipediaから得られた類義表現のうち、国語辞典からも抽出されるものを削除

# usage: perl check_dic_wikipedia_duplicate.pl -dic ../dic_change/isa.txt -wikipedia ../dic_middle/isa_wikipedia_aimai_merge.txt > ../dic_change/isa-wikipedia.txt 2> ../dic_change/isa-wikipedia.log

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
GetOptions(\%opt, 'dic=s', 'wikipedia=s', 'compound_noun_isa', 'exclude_head_same', 'debug');

my $LENGTH_MAX = 10;

my $HYPO_NUM_MAX = 5;

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
# まず上位語のみ
my %hypernym_data;
open(W, '<:encoding(euc-jp)', $opt{wikipedia}) or die;
while (<W>) {
    chomp;

    # アンパサンド 記号/きごう
    my ($hyponym, $hypernym, $num) = split("\t", $_);

    next if $num <= $HYPO_NUM_MAX;

    # 金谷:3/11       金谷駅  1
    next if $hyponym =~ /:\d+\/\d+/;
    $hypernym_data{$hypernym} = 1;

    # 教皇 -> ローマ教皇
    # 主辞が共通で下位語の方が短い
    next if $hypernym =~ /$hyponym$/;

    # 代表表記の場合、見出しも入れる
    if ($hypernym =~ /\//) {
	my ($midasi) = split(/\//, $hypernym);
	$hypernym_data{$midasi} = 1;
    }
}
close W;

# 複合名詞の主辞を上位語とする
# 例: 女性声優 -> 声優
# 例: 元プロ野球選手 -> プロ野球選手 -> 野球選手 -> 選手
my %compound_isa;
my %split_nakaguro;
if ($opt{compound_noun_isa}) {
    &generate_compound_isa;
}

my %outdata;
# Wikipediaデータの読み込み
open(W, '<:encoding(euc-jp)', $opt{wikipedia}) or die;
while (<W>) {
    chomp;

    # アンパサンド 記号/きごう
    my ($hyponym, $hypernym, $num) = split("\t", $_);

    next if $num <= $HYPO_NUM_MAX;

    # 下位語を持つものはそれ以上の上位語を獲得しない
    # 温泉 -> 用語
    if (defined $hypernym_data{$hyponym}) {
	print STDERR "!$hyponym has some hyponyms (上位語: $hypernym)\n";
	next;
    }

    my $midasi_hyponym = $hyponym;
    $midasi_hyponym =~ s/:\d+\/\d+//;

    # 長すぎる見出しはskip
#    next if (length $midasi_hyponym > $LENGTH_MAX);

    my $result = $knp->parse($midasi_hyponym);

    # 主辞が同じものを捨てる
    # 例: 川角駅	駅/えき
    if ($opt{exclude_head_same}) {
	if ($result) {
	    my $last_mrph = ($result->mrph)[-1];
	    next if $last_mrph->repname eq $hypernym || $last_mrph->midasi eq $hypernym;
	}
    }

    # 下位語がJUMAN内容語一語を捨てる
    # みお
    # 負けないで
    if (scalar ($result->tag) == 1) {
	# 未定義語 or 地名
	# アルデーノ
	if (scalar ($result->mrph) == 1 && ($result->mrph)[0]->fstring =~ /(?:<疑似代表表記>|地名)/) {
	    ;
	}
	# 全部英数字
	elsif ($hyponym =~ /^(?:\p{Latin}|\p{Common})+$/) {
	    ;
	}
	else {
	    next;
	}
    }
    # 辞書にもあるものを捨てる
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

    if (defined $split_nakaguro{$hypernym}) {
	for my $string (keys %{$split_nakaguro{$hypernym}}) {
	    $outdata{$string}{list}{$hyponym} = 1;
	    $outdata{$string}{num}++;
	}
    }
    else {
	$outdata{$hypernym}{list}{$hyponym} = 1;
	$outdata{$hypernym}{num}++;
#	print "$hyponym\t$hypernym\t$num\n";
    }
}
close W;

for my $hypernym (sort {$outdata{$b}{num} <=> $outdata{$a}{num} || $a <=> $b} keys %outdata) {
    my $num = $outdata{$hypernym}{num};
    for my $hyponym (sort keys %{$outdata{$hypernym}{list}}) {
	print "$hyponym\t$hypernym\t$num\n";
    }
}

if ($opt{compound_noun_isa}) {
    for my $hyper_cn (sort {scalar keys %{$compound_isa{$b}} <=> scalar keys %{$compound_isa{$a}}} keys %compound_isa) {
	my $num = scalar keys %{$compound_isa{$hyper_cn}};

	for my $hypo_cn (sort keys %{$compound_isa{$hyper_cn}}) {
	    print "$hypo_cn\t$hyper_cn\t$num\n";
	}
    }
}

sub generate_compound_isa {
    for my $hypernym (keys %hypernym_data) {

	next if $hypernym =~ /\//; # 体操/たいそう

	# 中黒でsplitできるかどうか (政治家・軍人)
	if (&check_split_nakaguro($hypernym)) {
	    for my $s (split('・', $hypernym)) {
		$split_nakaguro{$hypernym}{$s} = 1;
	    }
	    next;
	}

	my $result = $knp->parse($hypernym);

	my $mrph_num = scalar ($result->mrph);
	if ($mrph_num > 1) {
	    for (my $i = 0; $i < $mrph_num - 1; $i++) {

		next unless &is_start_mrph(($result->mrph)[$i]);

		my $j = 1; # hyper_cnを$iからいくつ後ろを見るか(デフォルト1)
		while ($i + $j < $mrph_num) {
		    if (&is_start_mrph(($result->mrph)[$i + $j])) {
			last;
		    }
		    $j++;
		}
		next if $i + $j == $mrph_num; 

		my $hypo_cn = &get_midasi($result, $i, $mrph_num - 1);
		my $hyper_cn = &get_midasi($result, $i + $j, $mrph_num - 1);

		# ５文字以下のカタカナは分割しない
		# プラグイン -> イン, カントン -> トン
		# 切ってもいいもの (ヒゲクジラ -> クジラ)
		# ６文字以上のもの (ファッションモデル -> モデル, ロックバンド -> バンド)
		next if $hypo_cn =~ /^\p{Katakana}{2,5}$/;

		next if length $hyper_cn == 1;

		print "$hypo_cn -> $hyper_cn\n" if $opt{debug};
		$compound_isa{$hyper_cn}{$hypo_cn} = 1;
	    }
	}
    }
}

# 政治学者・歴史学者 -> 政治学者, 歴史学者
# ロック・ギタリスト -> きらない

sub check_split_nakaguro {
    my ($string) = @_;

    return 0 if $string !~ /・/;

    my $flag = 1;
    for my $s (split('・', $string)) {
	# 下位語を持つ上位語があるかどうか
	if (!defined $hypernym_data{$s}) {
	    $flag = 0;
	}
    }

    if ($flag) {
	print STDERR "split $string (下位語を持つ)\n";
	return 1;
    }

    # 主辞の形態素が同じかどうか
    if (&check_same_last_mrph([split('・', $string)])) {
	print STDERR "same last mrph: $string\n";
	return 1;
    }

    print STDERR "No split: $string\n";
    return 0;
}

sub check_same_last_mrph {
    my ($strings) = @_;

    my $flag = 1;
    my $last_mrph_rep;

    for my $string (@$strings) {
	my $result = $knp->parse($string);

	if ($last_mrph_rep) {
	    if ($last_mrph_rep ne ($result->mrph)[-1]->repname) {
		$flag = 0;
		return 0;
	    }
	}
	else {
	    $last_mrph_rep = ($result->mrph)[-1]->repname;
	}
    }
    return 1;
}

# 複合名詞の開始となるか
sub is_start_mrph {
    my ($mrph) = @_;

    # 接尾辞
    # 中黒(例: 国学者・神道家)
    # ４０ｔｈシングル
    if ($mrph->hinsi eq '接尾辞' || $mrph->midasi =~ /^(?:・|ｔｈ|ｎｄ|ｒｄ|ｓｔ)$/) {
	return 0;
    }
    else {
	return 1;
    }
}

sub get_midasi {
    my ($result, $start, $end) = @_;

    my $midasi;

    # 1形態素
    if ($start == $end) {
	my $repname = ($result->mrph)[$start]->repname;
	$midasi = $repname =~ /\?/ ? ($result->mrph)[$start]->midasi : $repname;
    }
    else {
	for my $i ($start .. $end) {
	    $midasi .= ($result->mrph)[$i]->midasi;
	}
    }

    return $midasi;
}
