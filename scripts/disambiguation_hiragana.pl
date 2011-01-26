#!/usr/bin/env perl

# $Id$

# 類義表現グループ内のひらがな表記の曖昧性を解消するスクリプト

# usage: cat /somewhere/SynGraph/dic_change/synonym_dic.txt | perl disambiguation_hiragana.pl

use strict;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
use Getopt::Long;
use CalcSimilarityByCF;
use Configure;
use KNP;

my (%opt);
GetOptions(\%opt, 'help', 'debug');
&usage if $opt{help};

# 曖昧性解消するかどうかを決定する際の閾値
my $DISAMBIGUATE_TH = 0.3;
my $DISAMBIGUATE_RATIO = 3;

my $knp = new KNP( -Option => '-tab -dpnd',
		   -JumanCommand => $Configure::JumanCommand,
		   -JumanRcfile => $Configure::JumanRcfile);

my $cscf = new CalcSimilarityByCF( {debug => $opt{debug}} );

$cscf->TieMIDBfile($Configure::CalcsimMidbfile);

while (<>) {
    chomp;

    my $line = $_;

    my (@words) = split;

    my @data;

    my %disambiguate_result;

    # 技能/ぎのう:1/1:1/1
    foreach my $word (@words) {
	if ($word =~ /^(.+?)(\/.+?)?(:.+?)?$/) {
	    my $hyouki = $1;
	    my $yomi = $2;
	    my $id = $3;

	    push @data, { hyouki => $hyouki, yomi => $yomi, id => $id, word => "$hyouki$yomi", orig => $word };
	}
    }

    foreach my $target_data (@data) {
	my $target_hyouki = $target_data->{hyouki};
	my $target_yomi = $target_data->{yomi};
	my $target_id = $target_data->{id};

	# ひらがな単体
	if (!defined $target_yomi && !defined $target_id && $target_hyouki =~ /^\p{Hiragana}+$/) {
	    my $result = $knp->parse($target_hyouki);

	    my $repname = ($result->tag)[0]->repname;

	    # とりあえず一形態素
	    next if $repname =~ /\+/;

	    # とりあえず名詞
	    next if &get_pos($result) ne '名詞';

	    if (scalar ($result->tag) == 1 && $repname =~ /\?/) {
		print STDERR "★$target_hyouki, $repname: $line\n";

		my @cands = split (/\?/, $repname);

		my %score;
		foreach my $cand (@cands) {

		    print STDERR " ☆$cand\n";
		    my %already;
		    foreach my $data (@data) {
			# ひらがな、辞書にない、自分と同じもの、すでに計算したものを除く
			next if $data->{hyouki} =~ /^\p{Hiragana}+$/ || !defined $data->{id} || $target_hyouki eq $data->{hyouki} || defined $already{$data->{hyouki}};
			
			my $score = $cscf->CalcSimilarity($cand, $data->{word}, { method => 'Simpson', mifilter => 1});
			print STDERR "  $cand $data->{word} $score\n";

			$score{$cand}{score} += $score;
			$score{$cand}{datanum}++;
			$already{$data->{hyouki}} = 1;
		    }
		}

		# 最大スコアをもつものを決定
		if (keys %score >= 1) {
		    print STDERR "---\n";
		    my ($max_cand, $max_score);
		    foreach my $cand (sort { $score{$b} <=> $score{$a} } keys %score) {
			$score{$cand}{score_normalize} = $score{$cand}{score} / $score{$cand}{datanum};

			printf STDERR " %s %s %.3f\n", $cand, $score{$cand}{score}, $score{$cand}{score_normalize};

			# 最大値の更新
			if ($score{$cand}{score_normalize} >= $max_score) {
			    $max_score = $score{$cand}{score_normalize};
			    $max_cand = $cand;
			}
		    }
		    print STDERR "---\n";

		    # 曖昧性解消するかどうか
		    # $scoreが閾値以上かつ、その他の候補の$DISAMBIGUATE_RATIO倍以上scoreが高い
		    my $flag = 1;
		    if ($max_score >= $DISAMBIGUATE_TH) {
			foreach my $cand (sort { $score{$b} <=> $score{$a} } keys %score) {
			    next if $cand eq $max_cand;
			    if ($max_score <= $score{$cand}{score_normalize} * $DISAMBIGUATE_RATIO) {
				$flag = 0;
			    }
			}
		    }
		    else {
			$flag = 0;
		    }

		    if ($flag) {
			print STDERR " !! $max_cand\n";
			# $data->{word}が$candに曖昧性解消されたことを記憶しておく
			$disambiguate_result{$target_data->{word}} = $max_cand;

		    }
		    else {
			print STDERR " ! Not disambiguated\n";
		    }
		}
	    }
	}
    }

    # 出力
    if (scalar keys %disambiguate_result) {
	my @data_new;
	foreach my $data (@data) {
	    # 曖昧性解消された場合
	    if (defined $disambiguate_result{$data->{word}}) {
		push @data_new, $disambiguate_result{$data->{word}};
	    }
	    else {
		push @data_new, $data->{orig};
	    }
	}
	print join (' ', @data_new), "\n";
    }
    else {
	print $line, "\n";
    }
}

# 品詞を得る
sub get_pos {
    my ($result) = @_;

    if (scalar ($result->mrph) == 1) {
	return ($result->mrph)[0]->hinsi;
    }
    else {
	return '';
    }
}
