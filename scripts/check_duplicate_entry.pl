#!/usr/bin/env perl

# $Id$

# 同義表現リストから重複エントリを除くスクリプト

use strict;
use Getopt::Long;
use KNP;
use utf8;
use SynGraph;
use Configure;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

# merge: A=B, B=C, C=A のマージ
my %opt; GetOptions(\%opt, 'rnsame', 'merge', 'editdistance', 'read_multiple_entries', 'distributional_similarity', 'dicfile=s', 'debug');

my %upper2orig;

my $edit_distance;

# 欧州共同体 ＥＵ ＥＣ 1.5 0.523241082580591
# ＷＴＯ 国際貿易機関 世界観光機関 6 0.769830750246244
my $MERGE_TH_EDITDISTANCE = 0.5;

my $MERGE_TH_DISTRIBUTIONAL_SIMILARITY = 0.5;

my $juman;

if ($opt{dicfile}) {
    require Juman;
    $juman = new Juman(-Command => $Configure::JumanCommand,
		       -Rcfile => $Configure::JumanRcfile);
}

if ($opt{editdistance}) {
    require EditDistance;

    $edit_distance = new EditDistance({del_penalty => 1,
				      ins_penalty => 1,
				      rep_penalty => 1.5});
}

my $cscf;
if ($opt{distributional_similarity}) {
    require CalcSimilarityByCF;

    $cscf = new CalcSimilarityByCF({ method => 'Simpson' });

    $cscf->TieMIDBfile($Configure::CalcsimCNMidbfile);
}

my $knp = new KNP(-Option => '-tab -dpnd');

my (%data, %alldata);

my $same_counter = 0;
my $dup_counter = 0;
my $rnsame_counter = 0;

my @line;

my (%editdata);
my (%distributional_similarity_data);
my (%dic);
my (%dic_data);

# 国語辞典から曖昧性のない名詞間の同義関係を読み込む
&read_dicfile if $opt{dicfile};

if ($opt{read_multiple_entries}) {
    &read_input_multiple_entries;
}
else {
    &read_input;
}

&replace_synonym_dic if $opt{dicfile};

&calculate_editdistance if $opt{editdistance};

&calculate_distributional_similarity if $opt{distributional_similarity};

&merge if $opt{merge};

sub read_input {
    while (<>) {
	chomp;

	my ($word1, $word2) = split;

	my $word1_upper = &SynGraph::toupper($word1);
	$upper2orig{$word1_upper} = $word1;
	$word1 = $word1_upper;

	my $word2_upper = &SynGraph::toupper($word2);
	$upper2orig{$word2_upper} = $word2;
	$word2 = $word2_upper;

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
	    if ($opt{rnsame}) {
		my $repname1 = &GetRepname($word1);
		my $repname2 = &GetRepname($word2);

		if ($repname1 && $repname1 eq $repname2) {
		    print STDERR "☆REPNAME SAME synonym_web_news: $word1, $word2 ($repname1)\n";
		    $rnsame_counter++;
		    next;
		}
	    }

	    print "$word1 $word2\n" unless $opt{merge};
	    push @line, [ $word1, $word2 ];

	}
    }
}

sub read_input_multiple_entries {
    while (<>) {
	chomp;

#	$_ = Encode::decode('utf-8', $_);
	my (@words) = split;

	for (my $i = 0; $i < @words; $i++) {
	    for (my $j = $i + 1; $j < @words; $j++) {

		$alldata{$words[$i]}{$words[$j]} = 1;
		$alldata{$words[$j]}{$words[$i]} = 1;
	    }
	}
	push @line, \@words;
    }
}

sub read_dicfile {

    open (F, "<:encoding(utf-8)", $opt{dicfile}) || die;
    while (<F>){
	chomp;
	my $line = $_;

	# 名詞でない または 1/1:1/1でない（多義）があればパス
	my $flag = 1;
	my @words;
	for my $word (split (' ', $line)) {
	    # 精根/せいこん:1/1:1/1
	    if ($word =~ /^([^:]+):?(.+)?$/) {
		my $midasi = $1;
		my $id = $2;

		if ($midasi =~ /^(.+?)\//) {
		    $midasi = $1;
		}

		if ($id && $id ne '1/1:1/1') {
		    $flag = 0;
		    last;
		}
		my $result = $juman->analysis($midasi);
		# 名詞または名詞性名詞接尾辞（者、性など）でなければパス
		if (($result->mrph)[-1]->hinsi ne '名詞' && ($result->mrph)[-1]->bunrui ne '名詞性名詞接尾辞') {
		    $flag = 0;
		    last;
		}
		else {
		    push @words, $midasi;
		}
	    }
	}
	if ($flag) {
#	    for (my $i = 1; $i < @words; $i++) {
	    for (my $i = 0; $i < @words; $i++) {
		$dic{$words[$i]} = $words[0];
	    }
#	    print STDERR join (' ', @words), "\n";
	}
    }
    close F;
}

sub replace_synonym_dic {

    foreach my $target_word (keys %alldata) {
	my $replaced_word;

	my $result = $juman->analysis($target_word);
	my $replaced_flag = 0; # いずれかの形態素で置換されたかどうか

	# 1形態素のものはここでマージしなくてもいい
	next if scalar $result->mrph == 1;

	for my $mrph ($result->mrph) {
	    my $replaced_flag_mrph = 0; # この形態素が置換されたかどうか

	    foreach my $word (keys %dic) {
		if ($mrph->midasi eq $word) {
#		    print STDERR $mrph->midasi, " -> $dic{$word} ($target_word)\n";
		    $replaced_word .= $dic{$word};
		    $replaced_flag_mrph = 1;
		    $replaced_flag = 1;
		    last;
		}
	    }
	    unless ($replaced_flag_mrph) {
		$replaced_word .= $mrph->midasi;
	    }
	}
	if ($replaced_flag) {
	    $dic_data{$target_word} = $replaced_word;
	}
    }
}

# 編集距離の計算
sub calculate_editdistance {
    foreach my $target_word (keys %alldata) {
	foreach my $word1 (keys %{$alldata{$target_word}}) {
	    foreach my $word2 (keys %{$alldata{$target_word}}) {
		next if $word1 ge $word2;

		my ($distance) = $edit_distance->calc($word1, $word2);
		# 語長で正規化
		my $distance_normalized = $distance / (log(length($word1)) + 1) / (log(length($word2)) + 1);

		if ($distance_normalized < $MERGE_TH_EDITDISTANCE) {
		    print STDERR "☆Editdistance $target_word: $word1 <-> $word2 $distance $distance_normalized\n";

		    $editdata{$word1}{$word2} = $target_word;
		    $editdata{$word2}{$word1} = $target_word;
		}
	    }
	}
    }
}

# 分布類似度の計算
sub calculate_distributional_similarity {
    foreach my $target_word (keys %alldata) {
	foreach my $word1 (keys %{$alldata{$target_word}}) {
	    foreach my $word2 (keys %{$alldata{$target_word}}) {
		next if $word1 ge $word2;

		my $score = $cscf->CalcSimilarity($upper2orig{$word1}, $upper2orig{$word2}, { use_normalized_repname => 1, mifilter => 1 });

		if ($score >= $MERGE_TH_DISTRIBUTIONAL_SIMILARITY) {
		    print STDERR "☆DistributionalSimilarity $target_word: $word1 <-> $word2 $score\n";

		    $distributional_similarity_data{$word1}{$word2} = $target_word;
		    $distributional_similarity_data{$word2}{$word1} = $target_word;
		}
	    }
	}
    }
}

# A=B, B=C, C=Aのマージ
sub merge {
    my @merged_group;

    foreach my $line (@line) {
	my $new_group_flag = 1; # これが1のままの場合、新しいgroupを作る
	foreach my $synonym_group (@merged_group) {

	    my $merge_flag = 1; # これが1のままの場合、すでにあるグループにマージする
	    my %shared_word;
 	    foreach my $word (@{$line}) {
		if (defined $synonym_group->{$word}) {
		    $shared_word{$word} = 1;
		}
	    }

	    # 共有するものがなければnext
	    next if scalar keys %shared_word == 0;

 	    foreach my $word (@{$line}) {
		next if defined $shared_word{$word};

		my $flag = 0;
		foreach my $synonym_word (keys %{$synonym_group}) {
		    next if defined $shared_word{$synonym_word};

		    if ($word eq $synonym_word ||
			(defined $alldata{$word}{$synonym_word} || defined $alldata{$synonym_word}{$word}) || 
			($opt{dicfile} && defined $dic_data{$word} && defined $dic_data{$synonym_word} && $dic_data{$word} eq $dic_data{$synonym_word}) || 
			($opt{editdistance} && $editdata{$synonym_word}{$word} || $editdata{$word}{$synonym_word}) ||
 			($opt{distributional_similarity} && $distributional_similarity_data{$synonym_word}{$word} || $distributional_similarity_data{$word}{$synonym_word})) {
			$flag = 1;
			last;
		    }
		}
		unless ($flag) {
		    $merge_flag = 0;
		    last;
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

