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

my %opt; GetOptions(\%opt, 'synonym_rsk=s', 'synonym_web=s', 'definition=s', 'isa=s', 'antonym=s', 'convert_file=s', 'syndbdir=s');

# synparent.mldbm、synantonym.mldbmを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '../syndb/i686';


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
# 反義語の読み込み
#
if ($opt{antonym}) {
    open(ANT, '<:encoding(euc-jp)', $opt{antonym}) or die;
    my $ant_num;
    while (<ANT>) {
        chomp;
        my ($word1, $word2) = split(/ /, $_);

	# SYNIDを獲得
	my $word1_synlist = &get_synid($word1);
	my $word2_synlist = &get_synid($word2);
	foreach my $word1_synid (@$word1_synlist) {
	    foreach my $word2_synid (@$word2_synlist) {
		$antonym{$word1_synid}{$word2_synid} = 1;
		$antonym{$word2_synid}{$word1_synid} = 1;
		my $key_1 = (split(/:/, $word1))[0];
		my $key_2 = (split(/:/, $word2))[0];
		$log_antonym{"$word1_synid-$word2_synid"}{"$key_1-$key_2"} = 1;
		$log_antonym{"$word2_synid-$word1_synid"}{"$key_1-$key_2"} = 1;
#		$log_antonym{"$word1_synid-$word2_synid"}{"l.$ant_num\@isa.txt:$word1-$word2"} = 1;
#		$log_antonym{"$word2_synid-$word1_synid"}{"l.$ant_num\@isa.txt:$word1-$word2"} = 1;
	    }
	}
	$ant_num++;
    }
    close(ANT);
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
	my ($child, $parent) = split(/ /, $_);

	# SYNIDを獲得
        my $parent_list = &get_synid($parent);
	my $child_list = &get_synid($child);
	foreach my $parent_synid (@$parent_list) {
	    foreach my $child_synid (@$child_list) {
		$relation_parent{$child_synid}{$parent_synid} = 1;
		$relation_child{$parent_synid}{$child_synid} = 1;
		my $key_p = (split(/:/, $parent))[0];
		my $key_c = (split(/:/, $child))[0];
		$log_isa{"$child_synid-$parent_synid"}{"$key_c-$key_p"} = 1;
#		$log_isa{"$child_synid-$parent_synid"}{"l.$isa_num\@isa.txt:$child-$parent"} = 1;
	    }
	}
	$isa_num++;
    }
    close(ISA);
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
	foreach my $expression (@{$syn_group{$synid}}) {

	    # タグを取る
	    my $tag = $1 if $expression =~ s/<(定義文|RSK|Web)>$//g;
	    
	    # /（ふり仮名）:1/1:1/1:1/1などを取る
	    $expression = (split(/\//, $expression))[0];

            # 2文字以下のひらがなは無視
            next if ($expression =~ /^[ぁ-ん]+$/ and length($expression) <= 2);

            # 全角に変換
            $expression = &SynGraph::h2z($expression);

	    # 大文字に変換 ★小谷0425

            # 出力
            print CF "# S-ID:$synid,$expression\n";
            print CF "$expression\n";
            
            # いちばん
            if ($expression =~ /いちばん/) {
                $expression =~ s/いちばん/一番/;
                print CF "# S-ID:$synid,$expression\n";
                print CF "$expression\n";
            }

	    # 同義グループ情報
	    my $key_num = (split(/:/, $synid))[0];
	    $synnum{$key_num} = $synid;
	    $expression = $expression . "<$tag>" if $tag; # タグ付け
	    $syndb{$synid} .= $syndb{$synid} ? "|$expression" : "$expression";
        }
    }
    close(CF);
}


#
# 上位・下位関係の保存
#
&SynGraph::store_mldbm("$dir/synparent.mldbm", \%relation_parent);

#
# 反義関係の保存
#
&SynGraph::store_mldbm("$dir/synantonym.mldbm", \%antonym);

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
&SynGraph::store_mldbm("$dir/synchild.mldbm", \%relation_child);

#
# 上位下位関係のログ保存（CGI用）
#
&SynGraph::store_mldbm("$dir/log_isa.mldbm", \%log_isa);

#
# 反義関係のログ保存（CGI用）
#
&SynGraph::store_mldbm("$dir/log_antonym.mldbm", \%log_antonym);

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
