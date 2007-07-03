#!/usr/bin/env perl

# $Id$

# 辞書からの同義表現リストから重複エントリを除くスクリプト

use strict;
use Getopt::Long;
use Dumpvalue;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'debug', 'synonym_dic=s', 'log_merge=s', 'change=s');

my $knp = new KNP(-Option => '-tab -dpnd');

my %SYN;
open(SYN, '<:encoding(euc-jp)', $opt{synonym_dic}) or die;
while (<SYN>) {
    chomp;
    my @list = split;

    # ★要修正：同義グループ内に同じ言葉がないか

    # 要素数の数を調べる
    push @{$SYN{@list}}, $_;
}
close(SYN);
#Dumpvalue->new->dumpValue(\%SYN);

my @SYN_SORT;
# 要素数の多い順に同義グループを並び替える（要素数が多いものにマージする）
foreach my $num_of_word (sort {$b <=> $a} keys %SYN) {
    foreach my $group (@{$SYN{$num_of_word}}) {
	push @SYN_SORT, $group;
    }
}
#Dumpvalue->new->dumpValue(\@SYN_SORT);

open(LM, '>:encoding(euc-jp)', $opt{log_merge}) or die;    
open(CH, '>:encoding(euc-jp)', $opt{change}) or die;
my (%syngroup,  %result);
my $gr_number = 0;
foreach (@SYN_SORT) {
    my @list = split;

    # 重複check
    my %gr_check;
    my $flag;
    foreach my $word (@list) {
	last if ($flag); # 重複していない
	
	my $w = (split(/:/, $word))[0]; # ID取る
	($w, my $kana) = split(/\//, $w); # 振り仮名をとる
	$kana =~ s/v$//; # 「v」をとる
	if (defined $syngroup{$w} or ($kana and defined $syngroup{$kana}) or (!defined $kana and defined $syngroup{"/$w"})) { # 語が属している同義グループが存在する
	    if (%gr_check) { # 一番目の語が属している同義グループに二番目以降の語が属しているか？
		foreach my $g (keys %gr_check) {
		    next if ($w and defined $syngroup{$w} and grep($g eq $_, @{$syngroup{$w}}));
		    next if ($kana and defined $syngroup{$kana} and grep($g eq $_, @{$syngroup{$kana}}));
		    next if (!$kana and defined $syngroup{"/$w"} and grep($g eq $_, @{$syngroup{"/$w"}}));
		    delete $gr_check{$g}; # 二番目以降の語が属していないものを削除
		    unless (defined %gr_check) {
			$flag = 1; # 重複していない
			last;
		    }
		}
	    }
	    else { # 一番目の語が属している同義グループを調べる
		foreach my $g (@{$syngroup{$w}}) {
		    $gr_check{$g} = 1;
		}
		if (defined $kana) { # 一番目の語が代表表記化済み
		    $kana =~ s/v$//; # 「v」をとる
		    foreach my $g (@{$syngroup{"$kana"}}) { # 代表表記化されていないものが入っているグループを調べる
			$gr_check{$g} = 1 unless (defined $gr_check{$g});
		    }
		}
		else { # 一番目の語が代表表記化されていない
		    foreach my $g (@{$syngroup{"/$w"}}) { # 代表表記化されているものが入っているグループを調べる
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

    # 重複していたらマージ
    unless ($flag){ # 重複している

	# @listをマージする
	my $g;
	my $flag3; # マージ候補のどれかマージできた
	foreach $g (keys %gr_check) {
	    my @group_orig;
	    foreach (@{$result{$g}}) {
		push (@group_orig, $_);
	    }
	    # idやふり仮名をマージ
	    my @group_merge;
	    my $flag2; # マージできない
	    foreach my $word_orig (@group_orig) {
		my $flag4; # マージできた
		foreach my $word_delete (@list) {
		    last if ($flag2); # マージできなかった

		    my ($w_orig, $id_orig) = split(/:/, $word_orig, 2); # ID取る
		    ($w_orig, my $kana_orig) = split(/\//, $w_orig); # 振り仮名をとる
		    my ($w_delete, $id_delete) = split(/:/, $word_delete, 2); # ID取る
		    ($w_delete, my $kana_delete) = split(/\//, $w_delete); # 振り仮名をとる
		    
		    if ($w_orig eq $w_delete) { # マージ
			# if id_orig ne id_delete & kana_orig ne kana_delete 実はマージできない
			if (($id_orig and $id_delete and $id_orig ne $id_delete)
			    or ($kana_orig and $kana_delete and $kana_orig ne $kana_delete)) {
			    $flag2 = 1;
			    last; # マージできない
			}
			
			my $word_merge = $w_orig;
			if ($kana_orig) {
			    $word_merge .= "/$kana_orig";
			}
			elsif ($kana_delete) {
			    $word_merge .= "/$kana_delete";
			}
			if ($id_orig) {
			    $word_merge .= ":$id_orig";
			}
			elsif ($id_delete) {
			    $word_merge .= ":$id_delete";
			}
			push @group_merge, $word_merge;
			$flag4 = 1;
			last; # マージした
		    }
		    elsif (!(defined $kana_orig) and (($w_orig eq $kana_delete) or ($w_orig."v" eq $kana_delete))) { # origが代表表記化されていない
			# if id_orig ne id_delete & kana_orig ne kana_delete 実はマージできない
			if ($id_orig and $id_delete and $id_orig ne $id_delete) {
			    $flag2 = 1;
			    last; # マージできない
			}
			
			my $word_merge = "$w_delete/$kana_delete";
			if ($id_orig) {
			    $word_merge .= ":$id_orig";
			}
			elsif ($id_delete) {
			    $word_merge .= ":$id_delete";
			}
			push @group_merge, $word_merge;
			$flag4 = 1;
			last; # マージした
		    }
		    elsif (!(defined $kana_delete) and (($kana_orig eq $w_delete) or ($kana_orig eq $w_delete."v"))) { # deleteが代表表記化されていない
			# if id_orig ne id_delete & kana_orig ne kana_delete 実はマージできない
			if ($id_orig and $id_delete and $id_orig ne $id_delete) {
			    $flag2 = 1;
			    last; # マージできない
			}
			
			my $word_merge = "$w_orig/$kana_orig";
			if ($id_orig) {
			    $word_merge .= ":$id_orig";
			}
			elsif ($id_delete) {
			    $word_merge .= ":$id_delete";
			}
			push @group_merge, $word_merge;
			$flag4 = 1;
			last; # マージした
		    }
		}
		if ($flag2) { # マージできなかった
		    last;
		}
		elsif (!$flag4) { # @listになかった
		    push @group_merge, $word_orig;
		}
	    }
	    unless ($flag2) { # マージ
		delete $result{$g};
		push (@{$result{$g}}, @group_merge);
		
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
		my $merge_str;
		foreach (@group_merge) {
		    $merge_str .= " " if ($merge_str);
		    $merge_str .= $_;
		}
		
		print LM "<$orig_str> + <$delete_str> => <$merge_str>\n";
		$flag3 = 1; # マージできた
	    }
	}
	unless ($flag3) { # 実は重複していなかった。
	    # 新しい同義グループ登録
	    foreach my $word (@list) {
		push (@{$result{$gr_number}}, $word);
		my $w = (split(/:/, $word))[0]; # ID取る
		($w, my $kana) = split(/\//, $w); # 振り仮名をとる
		push (@{$syngroup{$w}},  $gr_number);
		# 仮名がついているものはそれからもひけるようにする。ただし、代表表記化されてないものと区別する。
		$kana =~ s/v$//; # 「v」をとる
		push (@{$syngroup{"/$kana"}},  $gr_number) if ($kana and ($w ne $kana));
	    }
	}
    }    
    else { # 重複していない
	
	# 新しい同義グループ登録
	foreach my $word (@list) {
	    push (@{$result{$gr_number}}, $word);
	    my $w = (split(/:/, $word))[0]; # ID取る
	    ($w, my $kana) = split(/\//, $w); # 振り仮名をとる
	    push (@{$syngroup{$w}},  $gr_number);
	    # 仮名がついているものはそれからもひけるようにする。ただし、代表表記化されてないものと区別する。
	    $kana =~ s/v$//; # 「v」をとる
	    push (@{$syngroup{"/$kana"}},  $gr_number) if ($kana and ($w ne $kana));
	}
    }
    $gr_number++;
}

# マージしたsynonym_dic出力
foreach my $num (sort {$a <=> $b} keys %result) {
    my $result_str;
    foreach my $word (@{$result{$num}}) {
	$result_str .= " " if ($result_str);
	$result_str .= $word;
    }
    print CH "$result_str\n";
}

close(CH);
close(LM);
