#!/usr/bin/env perl

# USAGE : perl -I../perl change_dic.pl --synonym=../dic_middle/synonym_dic.txt.merge.add --definition=../dic/rsk_iwanami/definition.txt --isa=../dic/rsk_iwanami/isa.txt.filtered --antonym=../dic_middle/antonym.txt.merge --synonym_change=synonym_dic.txt.merge.add.postprocess --isa_change=isa.txt --antonym_change=antonym.txt --definition_change=definition.txt --log=change.log --komidasi_num=../dic/rsk_iwanami/komidasi_num.txt

use strict;
use Dumpvalue;
use Getopt::Long;
use utf8;
use SynGraph;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %wordid;

my %opt; GetOptions(\%opt, 'synonym=s', 'definition=s', 'isa=s', 'antonym=s', 'synonym_change=s', 'isa_change=s', 'antonym_change=s', 'definition_change=s', 'log=s', 'komidasi_num=s');

# 多義でない語を記録
my %monosemy;
open (FILE, '<:encoding(euc-jp)', $opt{komidasi_num}) || die;
while (<FILE>) {
    chomp;
    my ($rep, $komidasi_num) = split;
    $monosemy{$rep} = 1 if ($komidasi_num == 1);
}
close(FILE);

# ログ
open (LOG, '>:encoding(euc-jp)', $opt{log}) or die;

# synonym
open (FILE, '<:encoding(euc-jp)', $opt{synonym}) || die;
open (CHANGE, '>:encoding(euc-jp)', $opt{synonym_change}) or die;
while (<FILE>) {
    chomp;
    my $orig_list = $_;
    my $change_list;

    foreach my $word (split (/\s/, $orig_list)) {
	# 多義でない語は「:1/1:1/1」を付与
	# ひらがな二文字は削除
	# 半角を全角に
	my $change_w = &change($word);
	$change_list .= $change_list ? " $change_w" : $change_w;
    }

    # 整形語に同義グループの要素数が１個になった場合はその同義グループを削除
    if ((split(/\s/, $change_list)) > 1) {
	print CHANGE "$change_list\n";

	# 同義グループの要素に変化があったらログを残す
	if ($orig_list ne $change_list) {
	    print LOG "★delete <$orig_list>\n";
	    print LOG "★change <$change_list>\n\n";
	}
    }
    else {
	# 同義グループの要素に変化があったのでログを残す
	print LOG "★delete <$orig_list>\n\n";
    }
}
close(FILE);
close(CHANGE);


# isa, antonym, definition
foreach my $Filetype ('isa', 'antonym', 'definition') {
    open (FILE, '<:encoding(euc-jp)', $opt{$Filetype}) || die;
    my $open_file = $Filetype . '_change';
    open (CHANGE, '>:encoding(euc-jp)', $opt{$open_file}) or die;
    while (<FILE>) {
	chomp;
	my $orig_list = $_;
	my $change_list;

	# 上位下位のときのみ、$numに数字が入る
	my ($word1, $word2, $num) = split (/\s/, $orig_list);
	my $delete_flag;
	foreach my $word ($word1, $word2) {
	    # 多義でない語は「:1/1:1/1」を付与
	    # ひらがな二文字は削除
	    # 半角を全角に
	    my $change_w = &change($word);
	    if ($change_w) {
		$change_list .= $change_list ? " $change_w" : $change_w;
	    }
	    else { # 関係を削除
		$delete_flag = 1;
		last;
	    }
	}
	$change_list .= " $num" if ($num); # isaのみ

	if ($delete_flag) {
	    # 関係が削除されたのでログを残す
	    print LOG "★delete <$orig_list>\n\n";
	}
	else {
	    print CHANGE "$change_list\n";
	    
	    # 同義グループの要素に変化があったらログを残す
	    if ($orig_list ne $change_list) {
		print LOG "★delete <$orig_list>\n";
		print LOG "★change <$change_list>\n\n";
	    }
	}
    }
    close(FILE);
    close(CHANGE);
}

close(LOG);

###############################################################################################
sub change {
    my ($word) = @_;

    # wordIDがついているか
    if ((split(/:/, $word, 2))[1]) {
	# wordIDがついていればそのまま返す
	return $word;
    }
    else {
	# 代表表記かどうか
	if ($word =~ /.+?\/.+?/) {
	    if ($monosemy{$word}) {
		# 多義でない語は「:1/1:1/1」を付与
		return "$word:1/1:1/1";
	    }
	    else {
		return $word;
	    }
	}
	else { # 代表表記でない
	    # 2文字以下のひらがなは無視
	    if ($word =~ /^[ぁ-ん]+$/ and length($word) <= 2){
		return;
	    }
	    else {
		# 全角に変換
		if ($word ne &SynGraph::h2z($word)) {
		    $word = &SynGraph::h2z($word);
		}
		return $word;
	    }
	}
    }
}
