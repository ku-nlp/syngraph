#!/usr/local/bin/perl

use strict;
use Dumpvalue;
use Getopt::Long;
use utf8;
use SynGraph;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %wordid;

my %opt; GetOptions(\%opt, 'synonym=s', 'definition=s', 'isa=s', 'antonym=s', 'synonym_change=s', 'isa_change=s', 'antonym_change=s', 'definition_change=s', 'log=s');

# 多義性が曖昧な語をチェック
my %check;
foreach my $Filetype ('synonym', 'definition', 'isa', 'antonym') {
    open (FILE, '<:encoding(euc-jp)', $opt{$Filetype}) || die;
    while (<FILE>) {
	chomp;
	my @words = split;
	
	foreach my $word (@words) {
	    next if ($check{$word});

	    $check{$word} = 1;
	    if ((split(/:/,$word,2))[1]) {
		my $w = (split(/:/,$word,2))[0]; 
		push @{$wordid{$w}}, $word;
	    }
	}
    }
    close(FILE);
}

# ログ
open (LOG, '>:encoding(euc-jp)', $opt{log}) or die;

# synonymは多義性を展開
# ひらがな二文字は削除
# 半角を全角に
open (FILE, '<:encoding(euc-jp)', $opt{synonym}) || die;
open (CHANGE, '>:encoding(euc-jp)', $opt{synonym_change}) or die;
while (<FILE>) {
    chomp;
    my @list = split (/\s/, $_);
    my @c_list;
    my @log;

    foreach my $word (@list) {
	if ((split(/:/, $word, 2))[1]) {
	    push @c_list, $word;
	}
	else {
	    if ($word =~ /.+?\/.+?/) {
		if ($wordid{$word}) {
		    # 多義性を展開
		    push @c_list, @{$wordid{$word}};
		    push @log, "$word → " . join(" ", @{$wordid{$word}});
		}
		else {
		    push @c_list, $word;
		}
	    }
	    else {
		# 2文字以下のひらがなは無視
		if ($word =~ /^[ぁ-ん]+$/ and length($word) <= 2){
		    # ログ
		    push @log, "★short $word → X\n";
		    next;
		}

		# 全角に変換
		if ($word ne &SynGraph::h2z($word)) {
		    # ログ
		    push @log, "★h2z $word → " . &SynGraph::h2z($word) . "\n";
		    $word = &SynGraph::h2z($word);
		}

		push @c_list, $word;
	    }
	}
    }

    print CHANGE join(" ", @c_list) . "\n";
    if (@log) {
	print LOG "★delete <" . join(" ", @list) . ">\n";
	foreach (@log) {
	    print LOG "★detail $_\n";
	}
	print LOG "★change <" . join(" ", @c_list) . ">\n\n";
    }
}
close(FILE);
close(CHANGE);

# isa, antonymは関係を展開
foreach my $Filetype ('isa', 'antonym', 'definition') {
    open (FILE, '<:encoding(euc-jp)', $opt{$Filetype}) || die;
    my $open_file = $Filetype . '_change';
    open (CHANGE, '>:encoding(euc-jp)', $opt{$open_file}) or die;
    while (<FILE>) {
	chomp;
	# 上位下位のときのみ、$numに数字が入る
	my ($word1, $word2, $num) = split (/\s/, $_);
	my %word_list;

	my $delete_flag;
	foreach my $word ($word1, $word2) {
	    if ((split(/:/, $word, 2))[1]) {
		push @{$word_list{$word}}, $word;
	    }
	    else {
		if ($word =~ /.+?\/.+?/) {
		    if ($wordid{$word}) {
			# 多義性を展開
			push @{$word_list{$word}}, @{$wordid{$word}};
		    }
		    else {
			push @{$word_list{$word}}, $word;
		    }
		}
		else {
		    # 2文字以下のひらがなは無視
		    if ($word =~ /^[ぁ-ん]+$/ and length($word) <= 2){
			$delete_flag = 1;
			last;
		    }
		    
		    # 全角に変換
		    if ($word ne &SynGraph::h2z($word)) {
			$word = &SynGraph::h2z($word);
		    }
		    
		    push @{$word_list{$word}}, $word;
		}
	    }
	}
	
	# 削除
	if ($delete_flag) {
	    next;
	}
	
	# 出力
	foreach my $w1 (@{$word_list{$word1}}) {
	    foreach my $w2 (@{$word_list{$word2}}) {
		print CHANGE $Filetype eq 'isa' ? "$w1 $w2 $num\n" : "$w1 $w2\n";
	    }
	}
    }

    close(FILE);
    close(CHANGE);
}
close(LOG);
