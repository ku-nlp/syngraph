#!/usr/bin/env perl

# $Id$

# 同義表現リストから重複エントリを除くスクリプト

use strict;
use Getopt::Long;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

# merge: A=B, B=C, C=A のマージ
my %opt; GetOptions(\%opt, 'rnsame', 'merge', 'editdistance', 'debug');

my $edit_distance;

# 欧州共同体 ＥＵ ＥＣ 1.5 0.523241082580591
# ＷＴＯ 国際貿易機関 世界観光機関 6 0.769830750246244
my $MERGE_TH_EDITDISTANCE = 0.5;

if ($opt{editdistance}) {
    require EditDistance;

    $edit_distance = new EditDistance({del_penalty => 1,
				      ins_penalty => 1,
				      rep_penalty => 1.5});
}

my $knp = new KNP(-Option => '-tab -dpnd');

my (%data, %alldata);

my $same_counter = 0;
my $dup_counter = 0;
my $rnsame_counter = 0;

my @line;

while (<>) {
    chomp;

    my ($word1, $word2) = split;

    if ($word1 eq $word2) {
	print STDERR "★same entry synonym_web_news: $word1, $word2\n";
	$same_counter++;
	next;
    }

    if ($word1 gt $word2) {
	my $tmp = $word1;
	$word1 = $word2;
	$word2 = $tmp;
    }

    if (defined $data{$word1}{$word2}) {
	print STDERR "★duplicate entry synonym_web_news: $word1, $word2\n";
	$dup_counter++;
    }
    else {
	$data{$word1}{$word2} = 1;

	$alldata{$word1}{$word2} = 1;
	$alldata{$word2}{$word1} = 1;

	# 代表表記が同じ
	if ($opt{rnsame} && &GetRepname($word1) && &GetRepname($word1) eq &GetRepname($word2)) {
	    print STDERR "☆REPNAME SAME synonym_web_news: $word1, $word2\n";
	    $rnsame_counter++;
	    next;
	}

	print "$word1 $word2\n" unless $opt{merge};
	push @line, [ $word1, $word2 ];

    }
}

my %editdata;
my %editdistance;
if ($opt{editdistance}) {
    foreach my $target_word (keys %alldata) {
	foreach my $word1 (keys %{$alldata{$target_word}}) {
	    foreach my $word2 (keys %{$alldata{$target_word}}) {
		next if $word1 ge $word2;

		my ($distance) = $edit_distance->calc($word1, $word2);
		# 語長で正規化
		my $distance_normalized = $distance / (log(length($word1)) + 1) / (log(length($word2)) + 1);

		$editdistance{$word1}{$word2} = $distance_normalized;

		if ($distance_normalized < $MERGE_TH_EDITDISTANCE) {
		    print STDERR "☆Editdistance $target_word: $word1 <-> $word2 $distance $distance_normalized\n";

		    $editdata{$word1}{$word2} = $target_word;
		    $editdata{$word2}{$word1} = $target_word;
		}
	    }
	}
    }
}

# A=B, B=C, C=Aのマージ
if ($opt{merge}) {
    my @merged_group;

    foreach my $line (@line) {
	my $new_group_flag = 1; # これが1のままの場合、新しいgroupを作る
	foreach my $synonym_group (@merged_group) {

	    my $merge_flag = 1; # これが1のままの場合、すでにあるグループにマージする
	    foreach my $word (@{$line}) {

		my $flag = 1;
		foreach my $synonym_word (keys %{$synonym_group}) {
		    if ($word eq $synonym_word ||
			(defined $alldata{$word}{$synonym_word} || defined $alldata{$synonym_word}{$word}) || 
			$opt{editdistance} && $editdata{$synonym_word}{$word} || $editdata{$word}{$synonym_word}) {
			;
		    }
		    else {
			$flag = 0;
			last;
		    }

		}
		# マージされない
		unless ($flag) {
		    $merge_flag = 0;
		}
	    }

	    if ($merge_flag) {
		print STDERR '★merge: ';
		foreach my $word (@{$line}) {
		    if (!defined $synonym_group->{$word}) {
			$synonym_group->{$word} = 1;
			print STDERR "$word ";
		    }
		}
		print STDERR 'to 【', join (' ', keys %{$synonym_group}), "】\n";

		$new_group_flag = 0;
	    }
	}
	if ($new_group_flag) {
	    # 足す
	    print STDERR '★create: ', join (' ', @{$line}), "\n";
	    push @merged_group, { map {$_ => 1} @{$line} };
	}
    }

    foreach my $merged_group (@merged_group) {
	print join (' ', keys %{$merged_group}), "\n";
    }
}

print STDERR "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"if ($same_counter | $dup_counter | $rnsame_counter);
print STDERR "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"if ($same_counter | $dup_counter | $rnsame_counter);
print STDERR "same entry:\t$same_counter\n" if $same_counter;
print STDERR "duplicate entry:\t$dup_counter\n" if $dup_counter;
print STDERR "rnsame entry:\t$rnsame_counter\n" if $rnsame_counter;
print STDERR "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"if ($same_counter | $dup_counter | $rnsame_counter);
print STDERR "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"if ($same_counter | $dup_counter | $rnsame_counter);

# 代表表記を得る
sub GetRepname {
    my ($word) = @_;

    my $result = $knp->parse($word);

    if (scalar ($result->bnst) == 1) {
	return ($result->bnst)[0]->repname;
    }
    else {
	return '';
    }
}

