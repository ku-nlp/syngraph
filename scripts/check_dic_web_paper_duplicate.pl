#!/usr/bin/env perl

# $Id$

# 辞書とWEBからの同義表現リストから重複エントリを除くスクリプト

use strict;
use Getopt::Long;
use Dumpvalue;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'dic=s', 'web=s', 'log_merge=s', 'change=s');

my $knp = new KNP(-Option => '-tab -dpnd');

my %syngroup;
my %wordbelong;
my $groupnum;
open(DIC, '<:encoding(euc-jp)', $opt{dic}) or die;
while (<DIC>) {
    chomp;
    my @list = split;

    # 同義グループ登録
    push (@{$syngroup{$groupnum}}, @list);
    # 属している語の登録
    foreach my $word (@list) {
	$word = (split(/:/, $word))[0]; # wordタグとる
	my ($w, $kana) = (split(/\//, $word))[0]; # かな
	push (@{$wordbelong{$w}}, $groupnum);
	if ($kana) {
	    $kana =~ s/v$//; # vをとる	    
	    push (@{$wordbelong{$kana}}, $groupnum);
	}
    }
    
    $groupnum++;
}
close(DIC);

open(WEB, '<:encoding(euc-jp)', $opt{web}) or die;
open(LM, '>:encoding(euc-jp)', $opt{log_merge}) or die;
open(CH, '>:encoding(euc-jp)', $opt{change}) or die;
while (<WEB>) {
    chomp;
    my @list = split;
    
    # 正規化

    # 重複check
    my %gr_check;
    my $flag;
    foreach my $word (@list) { # web辞書は代表表記化していない
	last if ($flag); # 重複していない

	if (defined $wordbelong{$word} or defined $wordbelong{"/$word"}) { # 語が属している同義グループが存在する
	    if (%gr_check) { # 一番目の語が属している同義グループに二番目以降の語が属しているか？
		foreach my $g (keys %gr_check) {
		    next if (grep($g eq $_, @{$wordbelong{$word}}));
		    delete $gr_check{$g}; # 二番目以降の語が属していないものを削除
		    if (scalar(keys %gr_check) == 0) {
			$flag = 1; # 重複していない
			last;
		    }
		}
	    }
	    else { # 一番目の語が属している同義グループを調べる
		if ($wordbelong{$word}) {
		    foreach my $g (@{$wordbelong{$word}}) {
			$gr_check{$g} = 1;
		    }
		}
		if ($wordbelong{"/$word"}) {
		    foreach my $g (@{$wordbelong{"/$word"}}) { # wordの代表表記化されているものが入っているグループを調べる
			$gr_check{$g} = 1 unless (defined $gr_check{$g});
		    }
		}
	    }
	}
	else { # 語が属している同義グループが存在しない
	    $flag = 1; # 重複していない
	    last;
	}
    }
    
    # 重複していたら消去
    unless ($flag){ # 重複している
	my $log_str;

	foreach my $g (keys %gr_check) {
	    my @group_orig;
	    foreach (@{$syngroup{$g}}) {
		push (@group_orig, $_);
	    }
	    
	    # @listを消去する
	    # ログ
	    my $delete_str;
	    foreach (@list) {
		$delete_str .= " " if ($delete_str);
		$delete_str .= $_;
	    }
	    my $orig_str;
	    foreach (@group_orig) {
		$orig_str .= " " if ($orig_str);
		$orig_str .= $_;
	    }

	    $log_str .= "★delete <$delete_str>\n" unless ($log_str);
	    if (length($orig_str) > 40) {
		$log_str .= "\t<$orig_str>\n\t\t<= <$delete_str>\n\n";
	    }
	    else {
		$log_str .= "\t<$orig_str> <= <$delete_str>\n";
	    }
	}
	print LM "$log_str\n";
    }
    else { # 重複していない
	
	# そのまま書き出す
	my $ch_str;
	foreach my $word (@list) {
	    $ch_str .= " " if ($ch_str);
	    $ch_str .= $word;
	}    
	print CH "$ch_str\n";
    }
}

close(CH);
close(LM);
close(WEB);
