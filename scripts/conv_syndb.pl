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

my %opt; GetOptions(\%opt, 'synonym=s', 'synonym_ne=s', 'definition=s', 'relation=s', 'antonym=s', 'convert_file=s', 'syndbdir=s');

# synparent.mldbm、synantonym.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';


my %definition;                       # 語ID => 定義文の配列
my %syn_hash;                         # 表現 => SYNID
my %syn_group;                        # 同義グループ（SYNID => {entry} => 表現 => 1）
my %relation_parent;                  # 下位 => 上位
my %antonym;			      # 反義語 	

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
	my $synid = &get_synid($syn_list[0], 'synonym');
	
        # 同義グループを作る
        foreach my $syn (@syn_list) {
            $syn_group{$synid}->{entry}->{$syn} = 1;
            $syn_hash{$syn} = $synid;
	    
            # 定義文がある場合も登録
            if ($definition{$syn}) {
		$syn_group{$synid}->{entry}->{$definition{$syn}} = 1;
                $syn_hash{$definition{$syn}} = $synid;
                delete $definition{$syn};
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
	$word1 = &get_synid($word1, 'antonym');
	$word2 = &get_synid($word2, 'antonym');
	$antonym{$word1}{$word2} = 1;
	$antonym{$word2}{$word1} = 1;
    }
    close(ANT);
}

#
# 上位・下位の読み込み
# (上下関係は全てSYNIDで扱う)
#
if ($opt{relation}) {
    open(REL, '<:encoding(euc-jp)', $opt{relation}) or die;
    while (<REL>) {
        chomp;
	my ($child, $parent) = split(/ /, $_);

	# SYNIDを獲得
        $parent = &get_synid($parent, 'relation');
	$child = &get_synid($child, 'relation');
	$relation_parent{$child}{$parent} = 1;
    }
    close(REL);
}


#
# 余った定義文は同義グループを作って登録
#
foreach my $midasi (keys %definition) {

    my $synid = &get_synid($midasi, 'definition');
    $syn_group{$synid}->{entry}->{$midasi} = 1;
    $syn_group{$synid}->{entry}->{$definition{$midasi}} = 1;
    $syn_hash{$midasi} = $synid;
    $syn_hash{$definition{$midasi}} = $synid;
}


#
# 同義グループをファイルに書き出す
#
if ($opt{convert_file}) {
    open(CF, '>:encoding(euc-jp)', $opt{convert_file}) or die;

    foreach my $synid (keys %syn_group) {
        foreach my $expression (keys %{$syn_group{$synid}->{entry}}) {

            # :1/1:1/1:1/1などを取る
            $expression = (split(/:/, $expression))[0];

	    # ふり仮名をとる
	    $expression = (split(/\//, $expression))[0];

            # 2文字以下のひらがなは無視
            next if ($expression =~ /^[ぁ-ん]+$/ and length($expression) <= 2);

            # 全角に変換
            $expression = &SynGraph::h2z($expression);

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
# SYNIDを取得、なければ同義グループを作る
#
my $line_number = 0; # 同義グループ番号
sub get_synid {
    my ($word, $mode) = @_;
    my $synid; # 同義グループ名

#    if ($mode eq ('synonym'|'definition')) { # synonym.txt, synonym_ne.txt, 余ったdefinition.txtからの読み込み
    if ($mode =~ /^(synonym|definition)$/) { # synonym.txt, synonym_ne.txt, 余ったdefinition.txtからの読み込み
	# SYNIDの作成
	$synid = 's' . $line_number . ":" . (split(/:/, $word))[0];
	$line_number++;

	return $synid;
    }
    else{ # antony,.txt, relation.txtからの読み込み   
	# 同義グループにある場合はそのSYNIDを返す
	if ($syn_hash{$word}) {
	    return $syn_hash{$word};
	}
	# なければ同義グループ作成
	else {
	    # SYNIDを振る
	    $synid = 's' . $line_number . ":" . (split(/:/, $word))[0];
	    $line_number++;
	    
	    # グループに登録
	    $syn_group{$synid}->{entry}->{$word} = 1;
	    $syn_hash{$word} = $synid;
	    
	    # 定義文があるとき
	    if (@definition{$word}) {
		foreach (@definition{$word}) {
		    $syn_group{$synid}->{entry}->{$_} = 1;
		    $syn_hash{$_} = $synid;
		    delete @definition{$word};
		}
	    }
	    
	    # IDを返す
	    return $synid;
	}
    }
}

#
# SYNIDを取得、なければ同義グループを作る
#
sub get_synid_old {
    my ($word, $line_number, $label) = @_;

    # 同義グループにある場合はそのSYNIDを返す
    if ($syn_hash{$word}) {
        return $syn_hash{$word};
    }
    else {
        # SYNIDを振る
        my $synid = $label . $line_number . $word;

        # グループに登録
        $syn_group{$synid}->{entry}->{$word} = 1;
        $syn_hash{$word} = $synid;

        # 定義文があるとき
        if (@definition{$word}) {
	    foreach (@definition{$word}) {
		$syn_group{$synid}->{entry}->{$_} = 1;
		$syn_hash{$_} = $synid;
		delete @definition{$word};
	    }
	}
	
        # IDを返す
        return $synid;
    }
}
