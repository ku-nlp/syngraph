#!/usr/bin/env perl

# $Id$
# synonym_dic.txtを整理するスクリプト

use strict;
use MergeTxt;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

my $MergeTxt = new MergeTxt;

my @group_list;
while (<>) {
    chomp;
    push @group_list, $_;
}

# 要素数の多い順に同義グループを並び替える（要素数が多いものにマージする）
my @sort_group_list = $MergeTxt->sort_group(\@group_list);

my $syn_group = {};
my $gr_number = 0;
my $word_index = {};
foreach (@sort_group_list) {
    my @list = split;

    # 重複check
    my $gr_check = {};
    $gr_check = $MergeTxt->merge_check(\@list, $word_index);

    # マージ
    if (defined $gr_check) {
	my $log_list = $MergeTxt->merge_group($gr_check, \@list, $syn_group, $word_index);
	if (scalar(@{$log_list}) > 0) {
	    my $log_str = $MergeTxt->make_log('merge', $log_list);
	    print STDERR "$log_str";
	}
	else { # IDの違いで実はマージできない
 	    #マージできなかったら登録
 	    $MergeTxt->regist_list4merge(\@list, $gr_number, $syn_group, $word_index);
 	    $gr_number++;
	}
    }
    else { #マージできなかったら登録
	$MergeTxt->regist_list4merge(\@list, $gr_number, $syn_group, $word_index);
	$gr_number++;
    }
}

# マージしたsynonym_dic出力
foreach my $num (sort {$a <=> $b} keys %{$syn_group}) {

    if (defined $syn_group->{$num}) {
	my $result_str;
	foreach my $word (@{$syn_group->{$num}}) {
	    $result_str .= " " if ($result_str);
	    $result_str .= $word;
	}
	print "$result_str\n";
    }
}
