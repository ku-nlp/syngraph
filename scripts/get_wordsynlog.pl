#!/usr/bin/env perl

# $Id$
# 入力２語の同義関係のログをとるスクリプト

# usage: perl get_wordsynlog.pl -add_log ../dic_change/synonym_dic.txt.merge.add.log  帯びる/おびる:1/1:2/3 奏する/そうする:1/1:2/2

use strict;
use Getopt::Long;
use Encode;
use Dumpvalue;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

# 参照するテキスト
my %opt; GetOptions(\%opt, 'add_log=s');

# 入力
my ($input1, $input2);
if ($ARGV[0] && $ARGV[1]) {
    $input1 = decode('utf-8', $ARGV[0]);
    $input2 = decode('utf-8', $ARGV[1]);
}

my %word_synlog;
my @syn_listlist;
my $number;
if ($opt{add_log}) {
    open(ALOG, '<:encoding(utf-8)', $opt{add_log}) or die;
    while (<ALOG>) {
        chomp;
	
	if ($_ =~ /^★delete <(.+?)>$/) {
	    $syn_listlist[$number] = $1;
	    $number++;
	}
	elsif ($_ =~ /^！detail (.+?)→(.+?)$/) {
	    # ★delete <経緯/けいい:1/1:3/3 いきさつ/いきさつ>
	    # ！detail いきさつ/いきさつ→いきさつ/いきさつ:1/1:1/1
	    # 上記から<経緯/けいい:1/1:3/3 いきさつ/いきさつ(→いきさつ/いきさつ:1/1:1/1)>を生成
	    my $str;
	    foreach my $word (split(/ /, $syn_listlist[-1])) {
		$str .= " " if ($str);
		$str .= ($word eq $1) ? "$word(→$2)" : $word;
	    }
	    
	    # syn_listist[-1]を更新
	    $syn_listlist[-1] = $str;
	}
	elsif ($_ =~ /^☆change <(.+?)>$/ or $_ =~ /^☆add <(.+?)>$/) {

	    # $input1, $input2がともに含まれているか？
	    my ($flag1, $flag2);
	    foreach my $word (split(/ /, $1)) {
		$flag1 = 1 if ($input1 eq $word);
		$flag2 = 1 if ($input2 eq $word);
	    }
	    unless ($flag1 and $flag2) {
		undef @syn_listlist;
		undef $number;
		next;
	    }

	    # test
#	    print "$_\n";
#	    print join(" ", @syn_listlist) . "\n";

	    #$input1, $input2がともに含まれているので連結のログを作成
	    #準備として諸情報を確保
	    my @wordlist; # 同義とされる語
	    my %tag; #抽出元のエントリー
	    foreach my $synlist (@syn_listlist) {
		foreach my $word (split(/ /, $synlist)) {
		    if ($word =~ /^(.+?\/.+?):\d\/\d:\d\/\d$/) { # IDまでついている
			push @wordlist, $word if (!grep($word eq $_, @wordlist));
			$tag{$synlist} .= $tag{$synlist} ? " or $1" : $1;
		    }
		    elsif ($word =~ /^.+?\/.+?\(→(.+?\/.+?):\d\/\d:\d\/\d\)$/) { # 多義でないから「1:1/1:1」がついている
			push @wordlist, $1 if (!grep($1 eq $_, @wordlist));
		    }
		    else { # 代表表記、または文字列
			push @wordlist, $word if (!grep($word eq $_, @wordlist));
		    }
		}
		# 辞書抽出のタグ作成 from word3 or word2
		$tag{$synlist} = "[form $tag{$synlist}]";
	    }

	    #初期の関係
	    foreach my $synlist (@syn_listlist) {
		foreach my $word1 (split(/ /, $synlist)) {
		    my $w1 = &word_change($word1);
		    foreach my $word2 (split(/ /, $synlist)) {
			my $w2 = &word_change($word2);
			#$word_synlog{$w1}{$w2} = "$word1 = $word2 $tag{$synlist}" unless $w1 eq $w2;
			$word_synlog{$w1}{$w2} = "$word1 = $word2 <$synlist>" unless $w1 eq $w2;
		    }
		}
	    }
	    last if $word_synlog{$input1}{$input2};

	    # 関係の連結
	    my $lastflag;
	    push my @checklist, (keys %{$word_synlog{$input1}});
	    foreach my $w1 (@checklist) {
		last if ($lastflag);
		foreach my $w2 (keys %{$word_synlog{$w1}}) {
		    next if ($word_synlog{$input1}{$w2});
		    $word_synlog{$input1}{$w2} = $word_synlog{$input1}{$w1} . "\n" . $word_synlog{$w1}{$w2};
		    if ($w2 eq $input2) {
			$lastflag=1;
			last;
		    }
		    else {
			push @checklist, (keys %{$word_synlog{$w2}});
		    }
		}
	    }
	}
    }
}

if ($word_synlog{$input1}{$input2}) {
    print $word_synlog{$input1}{$input2} . "\n";
}
else {
    print "not found\n";
}

#
# 「いきさつ/いきさつ(→いきさつ/いきさつ:1/1:1/1)」から「いきさつ/いきさつ:1/1:1/1」を抽出
# それ以外はそのまま返す
#
sub word_change {
    my ($word) = @_;
    
    if ($word =~ /^.+?\/.+?\(→(.+?\/.+?:\d\/\d:\d\/\d)\)$/) { # 多義でないから「1:1/1:1」がついている
	return $1;
    }
    else {
	return $word;
    }
}

