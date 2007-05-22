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

my %opt; GetOptions(\%opt, 'synonym_rsk=s', 'synonym_web=s', 'definition=s', 'isa=s', 'antonym=s', 'convert_file=s', 'syndbdir=s', 'log_merge=s');

# synparent.mldbm、synantonym.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '../syndb/i686';


my %definition;                       # 語ID => 定義文の配列
my %syn_hash;                         # 表現 => SYNID
my %syn_group;                        # 同義グループ
my %relation_parent;                  # 上位下位関係情報
my %relation_child;                   # 下位上位？関係情報
my %rel_num;                          # 上位下位のレベル（下位語の数）
my %log_isa;                          # 上位下位ログ
my %log_antonym;                      # 反義ログ
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
# 同義語グループの読み込み
#
my %file = ('synonym_rsk' => '<RSK>', 'synonym_web' => '<Web>');
foreach my $file_type (keys %file) {
    if ($opt{$file_type}) {
	open(SYN, '<:encoding(euc-jp)', $opt{$file_type}) or die;
	while (<SYN>) {
	    chomp;
	    my @syn_list = split(/\s/, $_);
	    
	    # 数が多いのは使わない
	    next if (@syn_list > 40);
	    
	    # SYNIDの獲得
	    my $synid = 's' . $syn_number . ":" . (split(/:/, $syn_list[0]))[0];
	    $syn_number++;
	    
	    # 同義グループを作る
	    foreach my $syn (@syn_list) {
		my $syn_key = $syn . "$file{$file_type}";
		push (@{$syn_group{$synid}}, $syn_key);
		push (@{$syn_hash{$syn}}, $synid);
		
		# 定義文がある場合も登録
		if ($definition{$syn}) {
		    my $def_key = $definition{$syn} . "<定義文>";
		    push (@{$syn_group{$synid}}, $def_key);
		    push (@{$syn_hash{$definition{$syn}}}, $synid);
		    $def_delete{$syn} = 1 if (!defined $def_delete{$syn});
		}
	    }
	}
	close(SYN);
    }
}


#
# 上位・下位の読み込み
# (上下関係は全てSYNIDで扱う)
#
if ($opt{isa}) {
    open(ISA, '<:encoding(euc-jp)', $opt{isa}) or die;
    my $isa_num;
    while (<ISA>) {
        chomp;
	my ($child, $parent, $number) = split(/ /, $_);
	$number = 3; # ★

	# SYNIDを獲得
        my $parentsyn_list = &get_synid($parent);
	my $childsyn_list = &get_synid($child);
	if (&contradiction_check($parentsyn_list, $childsyn_list)) {
	    if ($opt{log_merge}) {
		open(LM, '>:encoding(euc-jp)', $opt{log_merge}) or die;    
		print LM "X contradiction isa $child, $parent\n";
		close(LM);
	    }
	    next;
	}

	foreach my $parent_synid (@$parentsyn_list) {
	    foreach my $child_synid (@$childsyn_list) {
#		$relation_parent{$child_synid}{$parent_synid} = 1;
#		$relation_child{$parent_synid}{$child_synid} = 1;
		$relation_parent{$child_synid} .= $relation_parent{$child_synid} ? "|$parent_synid" : $parent_synid unless ($relation_parent{$child_synid} =~ /$parent_synid/);
		$relation_child{$parent_synid} .= $relation_child{$parent_synid} ? "|$child_synid" : $child_synid unless ($relation_child{$parent_synid} =~ /$child_synid/);
		my $key_p = (split(/:/, $parent))[0];
		my $key_c = (split(/:/, $child))[0];
#		$log_isa{"$child_synid-$parent_synid"}{"$key_c-$key_p"} = 1;
		$rel_num{"$child_synid-$parent_synid"} = $number if $rel_num{"$child_synid-$parent_synid"} < $number;
		$log_isa{"$child_synid-$parent_synid"} .= $log_isa{"$child_synid-$parent_synid"} ? "|$key_c-$key_p" : "$key_c-$key_p" unless $log_isa{"$child_synid-$parent_synid"} =~ /$key_c-$key_p/;
#		$log_isa{"$child_synid-$parent_synid"}{"l.$isa_num\@isa.txt:$child-$parent"} = 1;
	    }
	}
	$isa_num++;
    }
    close(ISA);
}


#
# 反義語の読み込み
#
if ($opt{antonym}) {
    open(ANT, '<:encoding(euc-jp)', $opt{antonym}) or die;
    my $ant_num;
    while (<ANT>) {
        chomp;
        my ($word1, $word2) = split(/ /, $_);

	# SYNIDを獲得
	my $word1syn_list = &get_synid($word1);
	my $word2syn_list = &get_synid($word2);
	if (&contradiction_check($word1syn_list, $word2syn_list)) {
	    if ($opt{log_merge}) {
		open(LM, '>:encoding(euc-jp)', $opt{log_merge}) or die;    
		print LM "X contradiction isa $word1, $word2\n";
		close(LM);
	    }
	    next;
	}

	foreach my $word1_synid (@$word1syn_list) {
	    foreach my $word2_synid (@$word2syn_list) {
#		$antonym{$word1_synid}{$word2_synid} = 1;
#		$antonym{$word2_synid}{$word1_synid} = 1;
		$antonym{$word1_synid} .= $antonym{$word1_synid} ? "|$word2_synid" : $word2_synid unless ($antonym{$word1_synid} =~ /$word2_synid/);
		$antonym{$word2_synid} .= $antonym{$word2_synid} ? "|$word1_synid" : $word1_synid unless ($antonym{$word2_synid} =~ /$word1_synid/);
		my $key_1 = (split(/:/, $word1))[0];
		my $key_2 = (split(/:/, $word2))[0];
#		$log_antonym{"$word1_synid-$word2_synid"}{"$key_1-$key_2"} = 1;
#		$log_antonym{"$word2_synid-$word1_synid"}{"$key_1-$key_2"} = 1;
		$log_antonym{"$word1_synid-$word2_synid"} .= $log_antonym{"$word1_synid-$word2_synid"} ? "|$key_1-$key_2" : "$key_1-$key_2" unless $log_antonym{"$word1_synid-$word2_synid"} =~ /$key_1-$key_2/;
		$log_antonym{"$word2_synid-$word1_synid"} .= $log_antonym{"$word2_synid-$word1_synid"} ? "|$key_1-$key_2" : "$key_1-$key_2" unless $log_antonym{"$word2_synid-$word1_synid"} =~ /$key_1-$key_2/;
#		$log_antonym{"$word1_synid-$word2_synid"}{"l.$ant_num\@isa.txt:$word1-$word2"} = 1;
#		$log_antonym{"$word2_synid-$word1_synid"}{"l.$ant_num\@isa.txt:$word1-$word2"} = 1;
	    }
	}
	$ant_num++;
    }
    close(ANT);
}


#
# 余った定義文は同義グループを作って登録
#
foreach my $midasi (keys %definition) {
    next if($def_delete{$midasi});

    # SYNIDの作成
    my $synid = 's' . $syn_number . ":" . (split(/:/, $midasi))[0];
    $syn_number++;

    my $midasi_key = $midasi . "<RSK>";
    my $def_key = $definition{$midasi} . "<定義文>";
    push (@{$syn_group{$synid}}, $midasi_key);
    push (@{$syn_group{$synid}}, $def_key);
    push (@{$syn_hash{$midasi}}, $synid);
    push (@{$syn_hash{$definition{$midasi}}}, $synid);
}


#
# 同義グループをファイルに書き出す
#
if ($opt{convert_file}) {
    open(CF, '>:encoding(euc-jp)', $opt{convert_file}) or die;    

    foreach my $synid (keys %syn_group) {
	my %check; # 曖昧性のある語の展開をチェック
	my $flag;
	foreach my $expression (@{$syn_group{$synid}}) {

	    # タグを取る
	    my $tag = $1 if $expression =~ s/<(定義文|RSK|Web)>$//g;
	    
	    # /（ふり仮名）:1/1:1/1:1/1などを取る
	    ($expression, my $kana, my $word_id) = split(/\/|:/, $expression);

	    # 曖昧性のある語の展開したものは一回しか数えない
	    next if $check{$expression};
	    $check{$expression} = 1;

            # 2文字以下のひらがなは無視
            next if ($expression =~ /^[ぁ-ん]+$/ and length($expression) <= 2);

            # 全角に変換
            $expression = &SynGraph::h2z($expression);

	    # 大文字に変換 ★小谷0425

            # 出力
            print CF "# S-ID:$synid,$expression\n";
            print CF "$expression\n";
            
            # いちばん
#             if ($expression =~ /いちばん/) {
#                 $expression =~ s/いちばん/一番/;
#                 print CF "# S-ID:$synid,$expression\n";
#                 print CF "$expression\n";
#             }

	    # 同義グループ情報
	    # １個目の語は正しいword_idがついている。２語目以降は展開の結果（暫定）
	    my $key_num = (split(/:/, $synid))[0];
	    $synnum{$key_num} = $synid;
	    $expression .= $flag ? $kana . "<$tag>" : $kana . $word_id . "<$tag>";
	    $syndb{$synid} .= $syndb{$synid} ? "|$expression" : "$expression";
	    $flag = 1;
        }
    }
    close(CF);
}


#
# 上位・下位関係の保存
#
&SynGraph::store_db("$dir/synparent.db", \%relation_parent);

#
# 反義関係の保存
#
&SynGraph::store_db("$dir/synantonym.db", \%antonym);

#
# 上位下位のレベル（下位語の数）
#
&SynGraph::store_db("$dir/synrel_num.db", \%rel_num);
#
# 同義グループの保存（CGI用）
#
&SynGraph::store_db("$dir/syndb.db", \%syndb);

#
# 同義グループ番号の保存（CGI用）
#
&SynGraph::store_db("$dir/synnumber.db", \%synnum);

#
# 下位・上位関係？の保存（CGI用）
#
&SynGraph::store_db("$dir/synchild.db", \%relation_child);

#
# 上位下位関係のログ保存（CGI用）
#
&SynGraph::store_db("$dir/log_isa.db", \%log_isa);

#
# 反義関係のログ保存（CGI用）
#
&SynGraph::store_db("$dir/log_antonym.db", \%log_antonym);

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
	my $word_key = $word . "<RSK>";
	push (@{$syn_group{$synid}}, $word_key);
        push (@{$syn_hash{$word}}, $synid);

        # 定義文があるとき
        if ($definition{$word}) {
	    my $def_key = $definition{$word} . "<定義文>";
	    push (@{$syn_group{$synid}}, $def_key);
	    push (@{$syn_hash{$definition{$word}}}, $synid);
	    $def_delete{$word} = 1 if (!defined $def_delete{$word});
	}
	
        # IDを返す
        return $syn_hash{$word};
    }
}

#
# 同義グループ間の矛盾のチェック（同義関係を優先）
#
sub contradiction_check {
    my ($list_1, $list_2) = @_;
    my $flag = 0;

    # $list_1$とlist_2に同じ同義グループがあるとだめ
    foreach my $element_1 (@$list_1) {
	last if ($flag);
	foreach my $element_2 (@$list_2) {
	    if ($element_1 eq $element_2) {
		$flag = 1;
		last;
	    }
	}
    }
    
    return $flag;
}
