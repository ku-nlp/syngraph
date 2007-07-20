#!/usr/bin/env perl

# $Id$
# antonym.txtを整理するスクリプト

use strict;
use Getopt::Long;
use MergeTxt;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my $MergeTxt = new MergeTxt;

my $ant_pair = {};
my $gr_number = 0;
my $word_index = {};
while (<>) {
    chomp;
    
    my @list = split;

    # 重複check
    my $gr_check = {};
    $gr_check = $MergeTxt->merge_check(\@list, $word_index);

    # マージ
    if (defined $gr_check) {
	my $log_list = $MergeTxt->merge_group($gr_check, \@list, $ant_pair, $word_index);
	if (scalar(@{$log_list}) > 0) {
	    my $log_str = $MergeTxt->make_log('merge', $log_list);
	    print STDERR "$log_str\n";
	}
	else { # IDの違いで実はマージできない
 	    #マージできなかったら登録
 	    $MergeTxt->regist_list4merge(\@list, $gr_number, $ant_pair, $word_index);
 	    $gr_number++;
	}
    }
    else { #マージできなかったら登録
	$MergeTxt->regist_list4merge(\@list, $gr_number, $ant_pair, $word_index);
	$gr_number++;
    }
}

# マージしたsynonym_dic出力
foreach my $num (sort {$a <=> $b} keys %{$ant_pair}) {
    my $result_str;
    foreach my $word (@{$ant_pair->{$num}}) {
	$result_str .= " " if ($result_str);
	$result_str .= $word;
    }
    print "$result_str\n";
}
