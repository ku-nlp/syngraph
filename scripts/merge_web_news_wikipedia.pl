#!/usr/bin/env perl

# $Id$

# 曖昧さ回避ページから抽出した多義語と、Webから獲得した同義語をマージ

# usage: perl -I../perl merge_web_news_wikipedia.pl -aimai ../dic/wikipedia/aimai_synonym_isa.txt -synonym_web_news ../dic_change/synonym_web_news.txt

use strict;
use Getopt::Long;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';
use Dumpvalue;
use Constant;
use CalcSimilarityByCF;

my %opt; GetOptions(\%opt, 'aimai=s', 'synonym_web_news=s', 'synonym_out=s', 'isa_out=s', 'debug');

my $cscf = new CalcSimilarityByCF( { skip_th => 1 });

$cscf->TieMIDBfile($Constant::CalcsimCNMidbfile);

my %data;
my @line_data;
my %merged_line;
my $line_num = 0;
open (F, "<:encoding(euc-jp)", $opt{synonym_web_news}) or die;
while (<F>) {
    chomp;

    my $line = $_;

    my (@words) = split;
    push @line_data, { line => $line, words => \@words };

    for my $word (@words) {
	$data{$word}{$line_num} = 1;
    }

    $line_num++;
}
close F;

my %aimai_data;
open (F, "<:encoding(euc-jp)", $opt{aimai}) or die;
# アドリアン:1/12	アドリアン・ナスターセ	synonym
while (<F>) {
    chomp;

    my ($word_id, $string, $type) = split("\t", $_);

    my ($word, $m, $n) = &get_word_id($word_id);

    $aimai_data{$word}{n} = $n;
    $aimai_data{$word}{list}{$m}{string} = $string;
    $aimai_data{$word}{list}{$m}{type} = $type;
}
close F;

for my $word (keys %aimai_data) {
    if (defined $data{$word}) {
	if ($opt{debug}) {
	    print STDERR "★$word\n";
	    for my $m (sort {$a <=> $b} keys %{$aimai_data{$word}{list}}) {
		print STDERR " $m: $aimai_data{$word}{list}{$m}{string} $aimai_data{$word}{list}{$m}{type}\n";
	    }
	    print STDERR "\n";
	}

	# 各同義語グループに対して
	for my $l (keys %{$data{$word}}) {
	    print STDERR $line_data[$l]{line}, "\n" if $opt{debug};

	    $merged_line{$l} = 1;

	    # 一番類似度の近い意味をみつける
	    my %similarity;
	    for my $w (@{$line_data[$l]{words}}) {
		next if $word eq $w;

		for my $m (sort {$a <=> $b} keys %{$aimai_data{$word}{list}}) {
		    my $string = $aimai_data{$word}{list}{$m}{string};

		    if ($w eq $string) {
			$similarity{$m} += 1;
		    }
		    else {
			my $sim = $cscf->CalcSimilarity($w, $string, { method => 'SimpsonJaccard', mifilter => 1});
			$similarity{$m} += $sim;
		    }
		}
	    }

	    my $max_sim = 0;
	    my $max_m;

	    for my $m (keys %similarity) {
		if ($similarity{$m} > $max_sim) {
		    $max_sim = $similarity{$m};
		    $max_m = $m;
		}
	    }

	    # すでにある意味とマージ
	    if ($max_m) {
		print STDERR "max_m: $max_m, max_sim: $max_sim ($line_data[$l]{line})\n" if $opt{debug};
		for my $w (@{$line_data[$l]{words}}) {
		    my $string = $aimai_data{$word}{list}{$max_m}{string};
		    # Webから獲得された同義語は代表表記化されていない(例:マウンテンバイク)ので、
		    # 代表表記(マウンテンバイク/マウンテンバイク)とのマッチも含む
		    next if $w eq $string || $w eq $word || $w eq (split('/', $string))[0];

		    if (!defined $aimai_data{$word}{list}{$max_m}{synonyms}{$w}) {
			$aimai_data{$word}{list}{$max_m}{synonyms}{$w} = 1;
		    }
		}

	    }
	    # 新しい意味を作る
	    else {
		print STDERR "new sense? ($line_data[$l]{line})\n" if $opt{debug};
		my $new_n = $aimai_data{$word}{n} + $aimai_data{$word}{new_n_num} + 1;
		$aimai_data{$word}{new_n_num}++;
		for my $w (@{$line_data[$l]{words}}) {
		    next if $w eq $word;

		    $aimai_data{$word}{list}{$new_n}{synonyms}{$w} = 1;
		}
	    }
	}
    }

    # 出力
    # Dumpvalue->new->dumpValue($aimai_data{$word});
    my $n = $aimai_data{$word}{n} + $aimai_data{$word}{new_n_num};
    for my $m (sort {$a <=> $b} keys %{$aimai_data{$word}{list}}) {
	if ($aimai_data{$word}{list}{$m}{type} eq 'synonym' || ! $aimai_data{$word}{list}{$m}{type}) {
	    print "$word:$m/$n\tsynonym";

	    if (defined $aimai_data{$word}{list}{$m}{string}) {
		print "\t", $aimai_data{$word}{list}{$m}{string};
	    }

	    if (defined $aimai_data{$word}{list}{$m}{synonyms}) {
		print "\t", join ("\t", keys %{$aimai_data{$word}{list}{$m}{synonyms}});
	    }
	    print "\n";
	}
	# 上位語
	if ($aimai_data{$word}{list}{$m}{type} eq 'isa') {
	    print "$word:$m/$n\tisa\t$aimai_data{$word}{list}{$m}{string}\n";

	    # 同義語
	    if (defined $aimai_data{$word}{list}{$m}{synonyms}) {
		print "$word:$m/$n\tsynonym", "\t", join ("\t", keys %{$aimai_data{$word}{list}{$m}{synonyms}}), "\n";
	    }
	}
    }
}

my %convert_data;
# 同義語の残りから多義語を見つける
for my $word (keys %data) {
    my $sense_num = 0;
    for my $l (keys %{$data{$word}}) {
	next if defined $merged_line{$l};

	$sense_num++;
    }

    # 多義語ならもう一周回す
    if ($sense_num > 1) {
	print STDERR "☆$word\n" if $opt{debug};

	my $s_num = 1;
	for my $l (keys %{$data{$word}}) {
	    next if defined $merged_line{$l};

	    $convert_data{$l}{$word} = "$word:$s_num/$sense_num";
	    $s_num++;
	}
    }
}

# print
for (my $l = 0; $l < @line_data; $l++) {
    next if defined $merged_line{$l};

    my @outputs;
    for my $word (@{$line_data[$l]{words}}) {
	if (defined $convert_data{$l} && defined $convert_data{$l}{$word}) {
	    push @outputs, $convert_data{$l}{$word};
	}
	else {
	    push @outputs, $word;
	}
    }
    print join("\t", @outputs), "\n";
}

sub get_word_id {
    my ($string) = @_;

    my ($word, $m, $n);
    if ($string =~ /^(.+):(\d+)\/(\d+)$/) {
	($word, $m, $n) = ($1, $2, $3);
    }
    else {
	print STDERR "Format Error ($string)\n";
    }

    return ($word, $m, $n);
}
