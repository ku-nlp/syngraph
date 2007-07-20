#!/usr/bin/env perl

# $Id$
# antonym.txt���������륹����ץ�

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

    # ��ʣcheck
    my $gr_check = {};
    $gr_check = $MergeTxt->merge_check(\@list, $word_index);

    # �ޡ���
    if (defined $gr_check) {
	my $log_list = $MergeTxt->merge_group($gr_check, \@list, $ant_pair, $word_index);
	if (scalar(@{$log_list}) > 0) {
	    my $log_str = $MergeTxt->make_log('merge', $log_list);
	    print STDERR "$log_str\n";
	}
	else { # ID�ΰ㤤�Ǽ¤ϥޡ����Ǥ��ʤ�
 	    #�ޡ����Ǥ��ʤ��ä�����Ͽ
 	    $MergeTxt->regist_list4merge(\@list, $gr_number, $ant_pair, $word_index);
 	    $gr_number++;
	}
    }
    else { #�ޡ����Ǥ��ʤ��ä�����Ͽ
	$MergeTxt->regist_list4merge(\@list, $gr_number, $ant_pair, $word_index);
	$gr_number++;
    }
}

# �ޡ�������synonym_dic����
foreach my $num (sort {$a <=> $b} keys %{$ant_pair}) {
    my $result_str;
    foreach my $word (@{$ant_pair->{$num}}) {
	$result_str .= " " if ($result_str);
	$result_str .= $word;
    }
    print "$result_str\n";
}
