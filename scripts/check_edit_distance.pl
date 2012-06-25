#!/usr/bin/env perl

# $Id$

# 編集距離の小さい同義語をまとめるスクリプト

# usage: perl -I/somewhere/Utils/perl check_edit_distance.pl < ../dic_change/synonym_web.txt

# Utils/perl/EditDistance.pmが必要

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';
use EditDistance;

my $MERGE_TH = 0.3;

my $edit_distance = new EditDistance({del_penalty => 1,
				      ins_penalty => 1,
				      rep_penalty => 1.5});


my %SYNONYM;

while (<>) {
    chomp;

    my ($word1, $word2) = split;

    $SYNONYM{$word1}{$word2} = 1;
    $SYNONYM{$word2}{$word1} = 1;
}

foreach my $target_word (keys %SYNONYM) {
    foreach my $word1 (keys %{$SYNONYM{$target_word}}) {
	foreach my $word2 (keys %{$SYNONYM{$target_word}}) {
	    next if $word1 le $word2;

	    my $distance = $edit_distance->calc($word1, $word2);
	    print "$target_word $word1 $word2 ",  $distance, " ", $distance / (log(length($word1)) + 1) / (log(length($word2)) + 1), "\n";
	}
    }
}

=comment
sub clustering {
    my $n = 0;		# これまでにマージした数
    my $cl = 0;		# これまでに作ったクラスタの数
    my @cl;		# ページが属しているクラスタ
    my @cl_m;		# クラスタのメンバリスト

    for my $s (sort {$b->{score} <=> $a->{score}} @scores) {

	# どちらもクラスタに属していない場合
	if (!defined($cl[$s->{i}]) and !defined($cl[$s->{j}])) {
	    last if $s->{score} < $new_threshold;

	    if ($opt{debug}){
 		print "New $cl ($s->{i}, $s->{j})\n";
 		printf "%.5f \n\t%d %s\n\t%d %s\n", $s->{score}, $s->{i}, $sentences[$s->{i}]{text}, $s->{j}, $sentences[$s->{j}]{text};
 	    }
 	    $cl[$s->{i}] = $cl;
 	    $cl[$s->{j}] = $cl;
 	    @{$cl_m[$cl]{members}} = ($s->{i}, $s->{j});
 	    $cl++;
 	}
 	# j側だけすでにクラスタに属している場合
 	elsif (!defined($cl[$s->{i}])) {
 	    next if $s->{score} < $threshold;

 	    if ($opt{debug}){
 		printf "Check %d to %d (%s)\n", $s->{i}, $cl[$s->{j}], join(', ', @{$cl_m[$cl[$s->{j}]]{members}});
 		printf "\t%d %s\n\t%d %s\n", $s->{i}, $sentences[$s->{i}]{text}, $s->{j}, $sentences[$s->{j}]{text};
 	    }	   
 	    next unless &check_score(\@score_index, [$s->{i}], $cl_m[$cl[$s->{j}]]{members});
 	    printf "Add %d to %d (%s)\n", $s->{i}, $cl[$s->{j}], join(', ', @{$cl_m[$cl[$s->{j}]]{members}}) if $opt{debug};
 	    $cl[$s->{i}] = $cl[$s->{j}];
 	    push(@{$cl_m[$cl[$s->{j}]]{members}}, $s->{i});
 	}
 	# i側だけすでにクラスタに属している場合
 	elsif (!defined($cl[$s->{j}])) {
 	    next if $s->{score} < $threshold;
 	    if ($opt{debug}){
 		printf "Check %d to %d (%s)\n", $s->{j}, $cl[$s->{i}], join(', ', @{$cl_m[$cl[$s->{i}]]{members}});
 		printf "\t%d %s\n\t%d %s\n", $s->{i}, $sentences[$s->{i}]{text}, $s->{j}, $sentences[$s->{j}]{text};
 	    }
 	    next unless &check_score(\@score_index, $cl_m[$cl[$s->{i}]]{members}, [$s->{j}]);
 	    printf "Add %d to %d (%s)\n", $s->{j}, $cl[$s->{i}], join(', ', @{$cl_m[$cl[$s->{i}]]{members}}) if $opt{debug};
 	    $cl[$s->{j}] = $cl[$s->{i}];
 	    push(@{$cl_m[$cl[$s->{i}]]{members}}, $s->{j});
 	}
 	# どちらもすでにクラスタに属している場合
 	else {
 	    next if $s->{score} < $threshold;
 	    next if $cl[$s->{i}] == $cl[$s->{j}];
 	    my $old_cl = $cl[$s->{i}];
 	    # どれか１つでも閾値にひっかかったらクラスタ化しない
 	    if ($opt{debug}){
 		printf "Check %d (%s) to %d (%s)\n", $old_cl, join(', ', @{$cl_m[$old_cl]{members}}), $cl[$s->{j}], join(', ', @{$cl_m[$cl[$s->{j}]]{members}});
 		printf "\t%d %s\n\t%d %s\n", $s->{i}, $sentences[$s->{i}]{text}, $s->{j}, $sentences[$s->{j}]{text};
 	    }		
 	    next unless &check_score(\@score_index, $cl_m[$cl[$s->{i}]]{members}, $cl_m[$cl[$s->{j}]]{members});
 	    printf "Merge %d (%s) to %d (%s)\n", $old_cl, join(', ', @{$cl_m[$old_cl]{members}}), $cl[$s->{j}], join(', ', @{$cl_m[$cl[$s->{j}]]{members}}) if $opt{debug};
	    
 	    for my $m (@{$cl_m[$old_cl]{members}}) {
 		$cl[$m] = $cl[$s->{j}];
 		push(@{$cl_m[$cl[$s->{j}]]{members}}, $m);
 	    }
 	    @{$cl_m[$old_cl]{members}} = ();
 	}
 	$n++;
    }

    # クラスタに属すページをマーク
    for my $i (0 .. $#sentences) {
	if (defined($cl[$i]) and scalar(@{$cl_m[$cl[$i]]{members}}) > 2) {
	    $sentences[$i]{cluster} = $cl[$i];
	}
	else {
	    $sentences[$i]{cluster} = undef;
	}
    }

    # 各クラスタにおいてメンバを昇順に
    for my $i (0 .. $#cl_m) {
 	@{$cl_m[$i]{members}} = sort {$a <=> $b} @{$cl_m[$i]{members}};
# 	sort {$a <=> $b} @{$cl_m[$i]}{members};
    }
    @cl_m = sort {@{$b->{members}} <=> @{$a->{members}}} @cl_m;

    return @cl_m;
}
=cut
