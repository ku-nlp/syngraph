#!/usr/local/bin/perl

# $Id$

use strict;
use Getopt::Long;
use CDB_File;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'synonym_dic=s', 'synonym_web_news=s', 'definition=s', 'isa=s', 'antonym=s', 'convert_file=s', 'syndbdir=s', 'log_merge=s', 'option=s', 'conv_log=s');

# synparent.mldbm、synantonym.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '../syndb/i686';

# option
my %option;
$option{$opt{option}}=1 if (defined $opt{option});

my @log_list;                         # covのlog
my %definition;                       # 語ID => 定義文の配列
my %syn_hash;                         # 表現 => SYNID
my %syn_group;                        # 同義グループ
my %relation_parent;                  # 上位下位関係情報
my %relation_child;                   # 下位上位？関係情報
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
my @file = ('synonym_dic', 'synonym_web_news');
foreach my $file_type (@file) {
    my $file_tag;
    if ($file_type eq 'synonym_dic') {
	$file_tag = '<DIC>';
    }
    elsif ($file_type eq 'synonym_web_news') {
	$file_tag = '<Web>';
    }
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
	    my @log;
	    foreach my $syn (@syn_list) {
		my $syn_key = $syn . "$file_tag";
		push (@{$syn_group{$synid}}, $syn_key);
		push (@{$syn_hash{$syn}}, $synid);
		
		# 定義文がある場合も登録
		if ($definition{$syn}) {
		    my $def_key = $definition{$syn} . "<定義文>";
		    push (@{$syn_group{$synid}}, $def_key);
		    push (@{$syn_hash{$definition{$syn}}}, $synid);
		    $def_delete{$syn} = 1 if (!defined $def_delete{$syn});

		    # ログ
		    push @log, "★definition <$syn $definition{$syn}>\n";
		}
	    }

	    # ログ
	    my $log_str = "★delete <" . join(" ", @syn_list) . ">\n";
	    foreach (@log) {
		$log_str .= "$_\n";		
	    }
	    $log_str .= "☆conv <" . join(" ", @{$syn_group{$synid}}) . ">\n\n";
	    push @log_list, $log_str;
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
    my %rel_synid;

    # 矛盾解消のログ
    if ($option{log} and $opt{log_merge}) {
	open(LM, '>>:encoding(euc-jp)', $opt{log_merge}) or die;
    }

    while (<ISA>) {
        chomp;
	my ($child, $parent, $number) = split(/ /, $_);

	# SYNIDを獲得
	my $childsyn_list = &get_synid($child);
        my $parentsyn_list = &get_synid($parent);
	if (&contradiction_check($parentsyn_list, $childsyn_list)) {
	    if ($option{log} and $opt{log_merge}) {
		print LM "X contradiction isa $child, $parent\n";
	    }
	    next;
	}

	foreach my $child_synid (@$childsyn_list) {
	    foreach my $parent_synid (@$parentsyn_list) {
		$rel_synid{$child_synid}->{$parent_synid} = $number if ((!defined $rel_synid{$child_synid}->{$parent_synid}) or ($rel_synid{$child_synid}->{$parent_synid} < $number)); # 最大数を記録,要相談
		# 上位下位のログ
		if ($option{log}) {
		    my $key_p = (split(/:/, $parent))[0];
		    $key_p = (split(/\//, $parent))[0];
		    my $key_c = (split(/:/, $child))[0];
		    $key_c = (split(/\//, $child))[0];
		    $log_isa{"$child_synid-$parent_synid"} .= $log_isa{"$child_synid-$parent_synid"} ? "|$key_c→$key_p" : "$key_c→$key_p" unless $log_isa{"$child_synid-$parent_synid"} =~ /$key_c→$key_p/; # なければ保存
		}
	    }
	}
    }
    foreach my $child_synid (keys %rel_synid) {
	foreach my $parent_synid (keys %{$rel_synid{$child_synid}}) {
	    # 上位グループ
	    $relation_parent{$child_synid} .= ($relation_parent{$child_synid} ? "|$parent_synid" : $parent_synid) . ",$rel_synid{$child_synid}->{$parent_synid}";
	    # 下位グループ(CGI用)
	    if ($option{log}) {
		$relation_child{$parent_synid} .= ($relation_child{$parent_synid} ? "|$child_synid" : $child_synid);
	    }
	}
    }

    if ($option{log} and $opt{log_merge}) {
	close(LM);
    }

    close(ISA);
}


#
# 反義語の読み込み
#
if ($opt{antonym}) {
    open(ANT, '<:encoding(euc-jp)', $opt{antonym}) or die;

    # 矛盾解消のログ
    if ($option{log} and $opt{log_merge}) {
	open(LM, '>>:encoding(euc-jp)', $opt{log_merge}) or die;    
    }

    while (<ANT>) {
        chomp;
        my ($word1, $word2) = split(/ /, $_);

	# SYNIDを獲得
	my $word1syn_list = &get_synid($word1);
	my $word2syn_list = &get_synid($word2);
	if (&contradiction_check($word1syn_list, $word2syn_list)) {
	    if ($option{log} and $opt{log_merge}) {
		print LM "X contradiction isa $word1, $word2\n";
	    }
	    next;
	}

	foreach my $word1_synid (@$word1syn_list) {
	    foreach my $word2_synid (@$word2syn_list) {
		$antonym{$word1_synid} .= $antonym{$word1_synid} ? "|$word2_synid" : "$word2_synid" unless ($antonym{$word1_synid} =~ /$word2_synid/);
		$antonym{$word2_synid} .= $antonym{$word2_synid} ? "|$word1_synid" : "$word1_synid" unless ($antonym{$word2_synid} =~ /$word1_synid/);

		# 反義関係のログ
		if ($option{log}) {
		    my $key_1 = (split(/\//, $word1))[0];
		    my $key_2 = (split(/\//, $word2))[0];
		    $log_antonym{"$word1_synid-$word2_synid"} .= $log_antonym{"$word1_synid-$word2_synid"} ? "|$key_1-$key_2" : "$key_1-$key_2" unless $log_antonym{"$word1_synid-$word2_synid"} =~ /$key_1-$key_2/;
		    $log_antonym{"$word2_synid-$word1_synid"} .= $log_antonym{"$word2_synid-$word1_synid"} ? "|$key_2-$key_1" : "$key_2-$key_1" unless $log_antonym{"$word2_synid-$word1_synid"} =~ /$key_2-$key_1/;
		}
	    }
	}
    }

    if ($option{log} and $opt{log_merge}) {
	close(LM);
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

    my $midasi_key = $midasi . "<DIC>";
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
	foreach my $expression (@{$syn_group{$synid}}) {

	    # タグを取る
	    my $tag = $1 if $expression =~ s/<(定義文|DIC|Web)>$//g;
	    
	    # :1/1:1/1:1/1を取る
	    ($expression, my $word_id) = split(/:/, $expression, 2);
	    $word_id = ":$word_id" if $word_id;

            # 出力
            print CF "# S-ID:$synid,$expression$word_id\n";
            print CF "$expression\n";
            
	    # 同義グループ情報
	    # $synid = 's517:趣/おもむき'
	    my $key_num = (split(/:/, $synid))[0];
	    $synnum{$key_num} = $synid;
	    if ($tag eq 'DIC') {
		$expression .= "$word_id" . "<$tag>";
	    }
	    else { # '定義文''Web'
		$expression .= "<$tag>";
	    }
	    $syndb{$synid} .= $syndb{$synid} ? "|$expression" : "$expression";
	}
    }
    close(CF);
}

#
# ログ
#
if ($opt{conv_log}) {
    open(LOG, '>:encoding(euc-jp)', $opt{conv_log}) or die;
    foreach (@log_list) {
	print LOG "$_";
    }
    close(LOG);
}

#
# 上位・下位関係の保存
#
&SynGraph::store_cdb("$dir/synparent.cdb", \%relation_parent);

#
# 反義関係の保存
#
&SynGraph::store_cdb("$dir/synantonym.cdb", \%antonym);

#
# 同義グループの保存（CGI用）
#
&SynGraph::store_cdb("$dir/syndb.cdb", \%syndb);

#
# 同義グループ番号の保存（CGI用）
#
if ($option{log}) {
    &SynGraph::store_cdb("$dir/synnumber.cdb", \%synnum);
}

#
# 下位・上位関係？の保存（CGI用）
#
if ($option{log}) {
    &SynGraph::store_cdb("$dir/synchild.cdb", \%relation_child);
}

#
# 上位下位関係のログ保存（CGI用）
#
if ($option{log}) {
    &SynGraph::store_cdb("$dir/log_isa.cdb", \%log_isa);
}

#
# 反義関係のログ保存（CGI用）
#
if ($option{log}) {
    &SynGraph::store_cdb("$dir/log_antonym.cdb", \%log_antonym);
}

print STDERR scalar(localtime), "辞書のコンバート終了\n";

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
	my $word_key = $word . "<DIC>";
	push (@{$syn_group{$synid}}, $word_key);
        push (@{$syn_hash{$word}}, $synid);

        # 定義文があるとき
	my @log;
        if ($definition{$word}) {
	    my $def_key = $definition{$word} . "<定義文>";
	    push (@{$syn_group{$synid}}, $def_key);
	    push (@{$syn_hash{$definition{$word}}}, $synid);
	    $def_delete{$word} = 1 if (!defined $def_delete{$word});

	    # ログ
	    push @log, "★definition <$word $definition{$word}>\n";
	}

	# ログ
	my $log_str = "★delete <$word>\n";
	foreach (@log) {
	    $log_str .= "$_\n";		
	}
	$log_str .= "☆conv <" . join(" ", @{$syn_group{$synid}}) . ">\n\n";
	push @log_list, $log_str;
	
        # IDを返す
        return $syn_hash{$word};
    }
}

#
# 同義グループ間の矛盾のチェック（同義関係を優先）
#
sub contradiction_check {
    my ($list_1, $list_2) = @_;

    # $list_1$とlist_2に同じ同義グループがあるとだめ
    # $list_1$とlist_2に語の多義性による同義グループがあるとだめ(s134:扱う/あつかう、s135:扱う/あつかう)
    foreach my $element_1 (@$list_1) {
	foreach my $element_2 (@$list_2) {
	    if ($element_1 eq $element_2) {
		return 1;
	    }
	    else {
		my $word1 = (split(/:/,$element_1))[1];
		my $word2 = (split(/:/,$element_2))[1];
		if ($word1 eq $word2) {
		    return 1;
		}
	    }
	}
    }
    
    return 0;
}
