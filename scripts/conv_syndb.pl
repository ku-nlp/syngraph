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
	$midasi = (split(/:/, $midasi))[0];
	
        # 定義文の例外
        $def =~ s/。$//;
        next if ($def =~ /(物ごと|…)/);
        next if ($def =~ /の(一つ|一種)$/);

        # こと・所を取る
        $def =~ s/のこと$//;
        $def =~ s/こと$//;
        $def =~ s/い所$/い/;

        # ハッシュに登録
	$definition{$midasi} = $def;
    }

    close(DEF);
}

#
# 同義語の読み込み
#
if ($opt{synonym}) {
    my @lines;
    open(SYN, '<:encoding(euc-jp)', $opt{synonym}) or die;
    while (<SYN>) {
	push @lines, $_;
    }
    close(SYN);

    my $line_number = 0;
    foreach (@lines) {
        $line_number++;
        chomp;

        # 数が多いのは使わない
	my @syn_list = split(/ /, $_);
	my @syn_conv_list;
	next if (@syn_list > 40);
        ###############################################################
        ## perl -ne 'split; print "$_[0]\t" . @_ . "\n";' < synonym.txt
        ## 上位10個
        ## 頻りに/しきりに:1/1:1/1:2/3     50
        ## 順序/じゅんじょ:1/1:1/1:1/1     50
        ## 遣り口/やりくち:1/1:1/1:1/1     45
        ## 風采/ふうさい:1/1:1/1:1/1       43
        ## 連日/れんじつ:1/1:1/1:1/1       34
        ## 間も無く/まもなく:1/1:1/1:1/1   25
        ## 頻りに/しきりに:1/1:1/1:1/3     24
        ## 益々/ますます:1/1:1/1:1/1       23
        ## 逐一/ちくいち:1/1:1/1:1/1       22
        ## 輪郭/りんかく:1/1:1/1:2/2       21
        ###############################################################

	my $num = 0;
	foreach (@syn_list) {
	    my $syn_word = $_;
	    $syn_word = (split(/:/,$syn_word))[0];
            $syn_word = $2 if ($syn_word =~ /(NORSK|AMB)\((.+?)\)/);
	    next if ($syn_word =~ /-/);
	    $syn_conv_list[$num] = $syn_word;
	    $num++;
	}

        # SYNID
        my $synid = 's' . $line_number . $syn_conv_list[0];

        # 同義グループを作る
        foreach my $syn (@syn_conv_list) {	    
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
    my $line_number = 0;

    open(SYN, '<:encoding(euc-jp)', $opt{antonym}) or die;
    while (<SYN>) {
        $line_number++;
        chomp;

        my ($word1_strings, $word2_strings) = split(/ /, $_);      

	# 曖昧性は全組み合わせ考える
	foreach my $word1 (split(/\?/, $word1_strings)) {
	    foreach my $word2 (split(/\?/, $word2_strings)) {
		$word1 = &get_synid($word1, $line_number, 'a');
		$word2 = &get_synid($word2, $line_number, 'a');
		$antonym{$word1}{$word2} = 1;
		$antonym{$word2}{$word1} = 1;
	    }
	}
    }
    close(SYN);
}

#
# 上位・下位の読み込み
# (上下関係は全てSYNIDで扱う)
#
if ($opt{relation}) {
    my $line_number = 0;

    open(REL, '<:encoding(euc-jp)', $opt{relation}) or die;
    while (<REL>) {
        $line_number++;
        chomp;
        next if (/<振>/);  # NORSK(海藻<振>かいそう</振>)

        # 数が多いの(もの、人、、、)は使わない
        my ($parent, @children) = split(/ /, $_);
	my @children_conv;
        next if (@children > 100);
        ####################################################################
        ## perl -ne 'split; print "$_[0]\t" . (@_-1) . "\n";' < relation.txt
        ## 上位20個
        ## 物/もの:1/1:1/1:1/7     870
        ## AMB(人/ひと)            696
        ## AMB(所/ところ)          342
        ## AMB(様子/ようす)        240
        ## AMB(言葉/ことば)        199
        ## 事/こと:1/1:1/1:1/4     168
        ## NORSK(ところ/ところ)    166
        ## AMB(国/くに)            158
        ## 道具/どうぐ:1/1:1/1:1/1 153
        ## 部分/ぶぶん:1/1:1/1:1/1 143
        ## AMB(力/ちから)          114
        ## NORSK(御/お-金/かね)    109
        ## AMB(気持ち/きもち)       96
        ## AMB(木/き)               92
        ## AMB(動物/どうぶつ)       83
        ## AMB(土地/とち)           77
        ## AMB(単位/たんい)         70
        ## AMB(場所/ばしょ)         70
        ## AMB(仕事/しごと)         70
        ## AMB(性質/せいしつ)       69
        ####################################################################

        # 上位語
	$parent = (split(/:/, $parent))[0];
	$parent = $2 if ($parent =~ /(NORSK|AMB)\((.+?)\)/);
	next if ($parent =~ /-/);
        $parent = &get_synid($parent, $line_number, 'r');

        # 下位語
	my $num = 0;
	foreach (@children) {
	    my $child_word = $_;
	    $child_word = (split(/:/,$child_word))[0];
            $child_word = $2 if ($child_word =~ /(NORSK|AMB)\((.+?)\)/);
	    next if ($child_word =~ /-/);
	    $children_conv[$num] = $child_word;
	    $num++;
	}
	
        foreach my $child (@children_conv) {
            $child = &get_synid($child, $line_number, 'r');
            $relation_parent{$child}{$parent} = 1;
        }
    }
    close(REL);
}


#
# 余った定義文は同義グループを作って登録
#
foreach my $midasi (keys %definition) {
    my $synid = 'd' . $midasi;
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

	    # ふり仮名をとる
	    $expression = (split(/\//, $expression))[0];

#            # ハイフンを繋げる
#            my @mrph_list = split(/\+/, $expression);
#            my $buf;
#            foreach my $mrph (@mrph_list) {
#                $buf .= (split(/\//, $mrph))[0];
#            }
#            $expression = $buf;

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
sub get_synid {
    my ($word, $line_number, $label) = @_;

    # 同義グループにある場合はそのSYNIDを返す
    if ($syn_hash{$word}) {
        return $syn_hash{$word};
    }
    else {
        # SYNIDを振る
        my $synid = $label . $line_number . $word;

        # ADJ、VERBは同義グループを作らない
        return $synid if ($word =~ /(ADJ|VERB)/);

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
