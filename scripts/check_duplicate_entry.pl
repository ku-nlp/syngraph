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
my %opt; GetOptions(\%opt, 'rnsame', 'merge', 'debug');

my $knp = new KNP(-Option => '-tab -dpnd');

my (%data, %alldata);

my $same_counter = 0;
my $dup_counter = 0;
my $rnsame_counter = 0;

my @line;
my $linenum = 0;
my %linedata;


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

	# 代表表記が同じ
	if ($opt{rnsame} && &GetRepname($word1) && &GetRepname($word1) eq &GetRepname($word2)) {
	    print STDERR "☆REPNAME SAME synonym_web_news: $word1, $word2\n";
	    $rnsame_counter++;
	    next;
	}

	print "$word1 $word2\n" unless $opt{merge};
	push @line, [ $word1, $word2 ];

	$linedata{$word1}{$linenum} = 1;
	$linedata{$word2}{$linenum} = 1;

	$linenum++;
    }
}

if ($opt{merge}) {
# A=B, B=C, C=Aのマージ
    my @merged_group;
    foreach my $word_A (sort { $a cmp $b } keys %data) {
	foreach my $word_B ( sort { $a cmp $b } keys %{$data{$word_A}}) {
	    next if $word_A ge $word_B;
	    my @registered;
	    foreach my $word_C ( sort { $a cmp $b } keys %{$data{$word_A}}) {
		next if $word_B ge $word_C;

		if (defined $data{$word_B}{$word_C}) {
		    # マージ候補にあがっているものと同義かどうかチェック
		    if (@registered) {
			my $flag = 1;
			foreach my $word (@registered) {
			    unless (defined $data{$word}{$word_C}) {
				$flag = 0;
				last;
			    }
			}
			if ($flag == 1) {
			    push @registered, $word_C;
			}
		    }
		    else {
			push @registered, $word_C;
		    }
		}
	    }
	    if (@registered) {
		# すでにできた同義グループのサブセットかどうかをチェック
		my $merge_flag = 1;
		foreach my $synonym_group (@merged_group) {
		    my $flag = 1;
		    foreach my $word (@registered) {
			if (!defined $synonym_group->{$word}) {
			    $flag = 0;
			    last;
			}
		    }
		    $flag = 0 unless defined $synonym_group->{$word_A} && defined $synonym_group->{$word_B};

		    if ($flag == 1) {
			$merge_flag = 0;
		    }
		}
		# マージ
		if ($merge_flag) {
		    my @newgroup = ( $word_A, $word_B, @registered );
		    print join (' ', @newgroup), "\n";

		    print STDERR "★merged: ", join (' ', @newgroup), "\n";

		    push @merged_group, { map {$_ => 1} @newgroup };

		    # すでにあったエントリの削除
		    for (my $i = 0; $i < @newgroup -1; $i++) {
			for (my $j = $i + 1; $j < @newgroup; $j++) {
			    my $word_i = $newgroup[$i];
			    my $word_j = $newgroup[$j];
			    foreach my $line (keys %{$linedata{$word_i}}) {
				if (defined $line[$line] && defined $linedata{$word_j}{$line}) {
				    $line[$line] = undef;

				    print STDERR "☆ deleted $word_i $word_j\n";
				}
			    }
			}
		    }
		}
	    }
	}
    }

    # 出力
    foreach my $line (@line) {
	if (defined $line) {
	    print join (' ', @{$line}), "\n";
	}
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

