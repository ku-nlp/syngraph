#!/usr/local/bin/perl

# $Id$

use strict;
use Getopt::Long;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'synonym=s', 'synonym_ne=s', 'definition=s', 'isa=s', 'antonym=s', 'convert_file=s', 'syndbdir=s');

# synparent.mldbm、synantonym.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';


my %definition;                       # 語ID => 定義文の配列
my %syn_hash;                         # 表現 => SYNID
my %syn_group;                        # 同義グループ
my %relation_parent;                  # 上位下位関係情報
my %antonym;			      # 反義関係情報
my %syndb;                            # 同義グループ
my %synnum;                           # 同義グループ番号情報
my $syn_number = 1;                   # 同義グループ番号
my %def_delete;

#
# 定義文の読み込み
#
if ($opt{definition}) {
    open(DEF, '<:encoding(euc-jp)', $opt{definition}) or die;
    while (<DEF>) {
        chomp;
        my ($midasi, $def) = split(/ /, $_);

        # 定義文の例外 （★★SYNGRAPH化してからとる）
        $def =~ s/。$//;
        next if ($def =~ /(物ごと|…)/);
        next if ($def =~ /の(一つ|一種)$/);

        # こと・所を取る （★★SYNGRAPH化してからとる）
        $def =~ s/のこと$//;
        $def =~ s/こと$//;
        $def =~ s/い所$/い/;

        # ハッシュに登録
	$definition{$midasi} = $def unless ($definition{$midasi});
    }

    close(DEF);
}

#
# 同義語の読み込み
#
if ($opt{synonym} or $opt{synonym_ne}) {
    my @lines;

    if ($opt{synonym}) {
	open(SYN, '<:encoding(euc-jp)', $opt{synonym}) or die;
	while (<SYN>) {
	    push @lines, $_;
	}
	close(SYN);
    }
    if ($opt{synonym_ne}) {
	open(SYN_NE, '<:encoding(euc-jp)', $opt{synonym_ne}) or die;
	while (<SYN_NE>) {
	    push @lines, $_;
	}
	close(SYN_NE);
    }

    foreach (@lines) {
        chomp;
	
        # 数が多いのは使わない
	my @syn_list = split(/\s/, $_);
	next if (@syn_list > 40);
	
        # SYNIDの獲得
	my $synid = 's' . $syn_number . ":" . (split(/:/, $syn_list[0]))[0];
	$syn_number++;

        # 同義グループを作る
        foreach my $syn (@syn_list) {
	    push (@{$syn_group{$synid}}, $syn);
            push (@{$syn_hash{$syn}}, $synid);
	    
            # 定義文がある場合も登録
            if ($definition{$syn}) {
		push (@{$syn_group{$synid}}, $definition{$syn});
                push (@{$syn_hash{$definition{$syn}}}, $synid);
		$def_delete{$syn} = 1 if (!defined $def_delete{$syn});
	    }
        }
    }
}

#
# 反義語の読み込み
#
if ($opt{antonym}) {
    open(ANT, '<:encoding(euc-jp)', $opt{antonym}) or die;
    while (<ANT>) {
        chomp;
        my ($word1, $word2) = split(/ /, $_);

	# SYNIDを獲得
	$word1 = &get_synid($word1);
	$word2 = &get_synid($word2);
	foreach my $word1_synid (@$word1) {
	    foreach my $word2_synid (@$word2) {
		$antonym{$word1_synid}{$word2_synid} = 1;
		$antonym{$word2_synid}{$word1_synid} = 1;
	    }    
	}
    }
    close(ANT);
}

#
# 上位・下位の読み込み
# (上下関係は全てSYNIDで扱う)
#
if ($opt{isa}) {
    open(REL, '<:encoding(euc-jp)', $opt{isa}) or die;
    while (<REL>) {
        chomp;
	my ($child, $parent) = split(/ /, $_);

	# SYNIDを獲得
        $parent = &get_synid($parent);
	$child = &get_synid($child);
	foreach my $parent_synid (@$parent) {
	    foreach my $child_synid (@$child) {
		$relation_parent{$child_synid}{$parent_synid} = 1;
	    }
	}
    }
    close(REL);
}


#
# 余った定義文は同義グループを作って登録
#
foreach my $midasi (keys %definition) {

    next if($def_delete{$midasi});

    # SYNIDの作成
    my $synid = 's' . $syn_number . ":" . (split(/:/, $midasi))[0];
    $syn_number++;

    push (@{$syn_group{$synid}}, $midasi);
    push (@{$syn_group{$synid}}, $definition{$midasi});
    push (@{$syn_hash{$midasi}}, $synid);
    push (@{$syn_hash{$definition{$midasi}}}, $synid);
}


#
# 同義グループをファイルに書き出す
#
if ($opt{convert_file}) {
    open(CF, '>:encoding(euc-jp)', $opt{convert_file}) or die;

#    foreach my $synid (keys %syn_group) {
#	foreach my $expression (keys %{$syn_group{$synid}->{entry}}) {
    foreach my $synid (keys %syn_group) {
	foreach my $expression (@{$syn_group{$synid}}) {

            # :1/1:1/1:1/1などを取る
            $expression = (split(/:/, $expression))[0];

	    # ふり仮名をとる
	    $expression = (split(/\//, $expression))[0];

            # 2文字以下のひらがなは無視
            next if ($expression =~ /^[ぁ-ん]+$/ and length($expression) <= 2);

            # 全角に変換
            $expression = &SynGraph::h2z($expression);

	    # 同義グループ作成
	    my $key_num = (split(/:/, $synid))[0];
	    $synnum{$key_num}{$synid} = 1;
	    $syndb{$synid} .= $syndb{$synid} ? " | $expression" : "$expression";

            # 出力
            print CF "# S-ID:$synid,$expression\n";
            print CF "$expression\n";
            
            # いちばん
            if ($expression =~ /いちばん/) {
                $expression =~ s/いちばん/一番/;
                print CF "# S-ID:$synid,$expression\n";
                print CF "$expression\n";
            }
        }
    }
    close(CF);
}


#
# 上位・下位関係の保存
#
&SynGraph::store_mldbm("$dir/synparent.mldbm", \%relation_parent);

#
# 反義語の保存
#
&SynGraph::store_mldbm("$dir/synantonym.mldbm", \%antonym);

#
# 同義グループの保存
#
&SynGraph::store_mldbm("$dir/syndb.mldbm", \%syndb);

#
# 同義グループ番号の保存
#
&SynGraph::store_mldbm("$dir/synnumber.mldbm", \%synnum);


#
# SYNIDを取得、なければ同義グループを作る
#
sub get_synid {
    my ($word) = @_;

    # 同義グループにある場合はそのSYNIDを返す
    if (defined $syn_hash{$word}) {
        return $syn_hash{$word};
    }
    else {
        # SYNIDを振る
	my $synid = 's' . $syn_number . ":" . (split(/:/, $word))[0];
	$syn_number++;

        # グループに登録
	push (@{$syn_group{$synid}}, $word);
        push (@{$syn_hash{$word}}, $synid);

        # 定義文があるとき
        if ($definition{$word}) {
	    push (@{$syn_group{$synid}}, $definition{$word});
	    push (@{$syn_hash{$definition{$word}}}, $synid);
	    $def_delete{$word} = 1 if (!defined $def_delete{$word});
	}
	
        # IDを返す
        return $syn_hash{$word};
    }
}
