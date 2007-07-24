#!/usr/bin/env perl

# 多義でない語を「1/1:1/1」に決め、多義でない語を用いてグループを連結するスクリプト

use strict;
use Getopt::Long;
use MergeTxt;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'noambiguity_file=s');

my $MergeTxt = new MergeTxt;

if ($opt{noambiguity_file}) {

    open(AMB, '<:encoding(euc-jp)', $opt{noambiguity_file}) or die;
    while (<AMB>) {
        chomp;
        my ($word, $word_and_id) = split(/ /, $_);
	
	$MergeTxt->{noambiguity_file}{$word} = 1 unless ($MergeTxt->{noambiguity_file}{$word});
    }    
}
#Dumpvalue->new->dumpValue($MergeTxt->{noambiguity_file});

my $syn_group = {};
my $gr_number = 0;
my $word_index = {};

while (<>) {
    chomp;
    
    my @list = split;

    # 多義でないものを「1/1:1/1」に決める
    my @c_list;
    my $flag;
    my @word_change_log;
    foreach my $word (@list) {
	if ($MergeTxt->{noambiguity_file}{$word}) {
	    my $c_word = "$word:1/1:1/1";
	    $flag = 1 unless ($flag);
	    push @c_list, $c_word;
	    push @word_change_log, "$word → $c_word";
	}
	else {
	    push @c_list, $word;
	}
    }
    if ($flag) {
	print STDERR "★delete <" , join(" ", @list), ">\n";
	foreach (@word_change_log) {
	    print STDERR "☆detail $_\n";
	}
	print STDERR "☆change <" , join(" ", @c_list), ">\n\n";
    }

    # 連結できる可能性check
    my $gr_check = {};
    $gr_check = $MergeTxt->add_check(\@c_list, $word_index);

    # 連結
    if (defined $gr_check) {

	# 連結したものを登録
	push my @group_add, @c_list;
	my $log;
	foreach my $add_g_number (keys %{$gr_check}) {

	    # add_groupに連結
	    @group_add =  $MergeTxt->add_group(\@group_add, $syn_group->{$add_g_number});
	    
	    # ログ
	    my $delete_str = join(" ", @{$syn_group->{$add_g_number}});
	    $log .= "★delete <$delete_str>\n";
	    
	    # add_g_number情報削除
	    $MergeTxt->delete_word_index(\@{$syn_group->{$add_g_number}}, $add_g_number, $word_index);
	    delete $syn_group->{$add_g_number};
	}
	
	# ログ
	my $delete_str = join(" ", @c_list);
	$log .= "★delete <$delete_str>\n";
	my $add_str = join(" ", @group_add);
	$log .= "☆add <$add_str>\n";
	
	# 連結したものを登録
	$MergeTxt->regist_list4add(\@group_add, $gr_number, $syn_group, $word_index);
	print STDERR "$log\n";
    }
    else {
	#連結できなかったら登録
	$MergeTxt->regist_list4add(\@c_list, $gr_number, $syn_group, $word_index);
    } 
    
    $gr_number++;
}

# 連結したsynonym_dic出力
my @result_list;
foreach my $num (sort {$a <=> $b} keys %{$syn_group}) {

    if (defined $syn_group->{$num}) {
	push @result_list, join(" ", @{$syn_group->{$num}});
    }
}

# 要素数の多い順に同義グループを並び替える
my @sort_result_list = $MergeTxt->sort_group(\@result_list);

foreach (@sort_result_list) {
#foreach (@result_list) {
    print "$_\n";
}
