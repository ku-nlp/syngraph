#!/usr/bin/env perl

use strict;
use Getopt::Long;
use CDB_File;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';
use File::Basename;

my %opt; GetOptions(\%opt, 'synonym_dic=s', 'synonym_web_news=s', 'definition=s', 'isa=s', 'isa_wikipedia=s', 'antonym=s', 'antonym_med=s', 'convert_file=s', 'syndbdir=s', 'syndbdir_cgi=s', 'log_merge=s', 'option=s', 'conv_log=s', 'wikipedia', 'isa_max_num=i', 'similarphrase=s', 'dic_user_dir=s');

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

# default
my %FILE = ( 'def' => [ 'definition' ],
	     'synonym' => [ 'synonym_dic', 'synonym_web_news' ],
	     'isa' => [ 'isa', 'isa_wikipedia' ],
	     'antonym' => [ 'antonym' ],
	     'similarphrase' => [ 'similarphrase' ]
    );
my %USER_DIC_FILENAME;
&read_dic_user_dir if $opt{dic_user_dir};

#
# 定義文の読み込み
#
foreach my $file_type (@{$FILE{'def'}}) {
    if ($opt{$file_type}) {
	open(DEF, '<:encoding(utf-8)', $opt{$file_type}) or die;

	while (<DEF>) {
	    chomp;

	    my ($midasi, $def);
	    if ($file_type eq 'definition_med') {
		($midasi, $def) = split(/ /, $_, 2);

		$midasi = &SynGraph::h2z($midasi);
		$def = &SynGraph::h2z($def);
	    }
	    else {
		($midasi, $def) = split(/ /, $_);
	    }


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
}

#
# 同義語グループの読み込み
#
foreach my $file_type (@{$FILE{'synonym'}}) {
    my $file_tag;
    if ($file_type eq 'synonym_dic') {
	$file_tag = '[DIC]';
    }
    elsif ($file_type eq 'synonym_web_news') {
	$file_tag = '[Web]';
    }
    else {
	my ($type, $name) = split('_', $file_type);
	$file_tag = "[$name]";
    }
    
    if ($opt{$file_type}) {
	open(SYN, '<:encoding(utf-8)', $opt{$file_type}) or die;
	while (<SYN>) {
	    chomp;
	    $_ = &SynGraph::h2z($_) if defined $USER_DIC_FILENAME{$file_type};
	    $_ = &SynGraph::toupper($_) if defined $USER_DIC_FILENAME{$file_type};

	    my $delimiter = (($file_type eq 'synonym_web_news' && $opt{wikipedia}) || defined $USER_DIC_FILENAME{$file_type}) ? '\t' : '\s';
	    my @syn_list = split(/$delimiter/, $_);
	    
	    # 数が多いのは使わない
	    next if $file_type ne 'synonym_ingo' && (@syn_list > 40);
	    
	    # SYNIDの獲得
	    my $synid = 's' . $syn_number . ':' . (split(/:/, $syn_list[0]))[0];
	    $syn_number++;
	    
	    # 同義グループを作る
	    my @log;
	    foreach my $syn (@syn_list) {
		my $syn_key = $syn . $file_tag;
		push (@{$syn_group{$synid}}, $syn_key);
		push (@{$syn_hash{$syn}}, $synid);
		
		# 定義文がある場合も登録
		if ($definition{$syn}) {
		    my $def_key = $definition{$syn} . '[定義文]';
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
foreach my $file_type (@{$FILE{'isa'}}) {
    if ($opt{$file_type}) {
	open(ISA, '<:encoding(utf-8)', $opt{$file_type}) or die;
	my %rel_synid;

	# 矛盾解消のログ
	if ($opt{log_merge}) {
	    open(LM, '>>:encoding(utf-8)', $opt{log_merge}) or die;
	}

	while (<ISA>) {
	    chomp;

	    my $delimiter = $file_type eq 'isa_wikipedia' ? '\t' : ' ';
	    my ($child, $parent, $number);
	    # ユーザ辞書には上位語数がない
	    if (defined $USER_DIC_FILENAME{$file_type}) {
		($child, $parent) = split(/\t/, $_);
		$child = &SynGraph::h2z($child);
		$parent = &SynGraph::h2z($parent);
	    }
	    else {
		($child, $parent, $number) = split(/$delimiter/, $_);
	    }

	    next if $opt{isa_max_num} && $file_type eq 'isa' && $number > $opt{isa_max_num};

	    # 文字化け対策
	    next if $child =~ /\?/ || $parent =~ /\?/;

	    my $tag;
	    if ($file_type eq 'isa_wikipedia') {
		$tag = '[Wikipedia]';
	    }
	    elsif (defined $USER_DIC_FILENAME{$file_type}) {
		my ($type, $name) = split('_', $file_type);
		$tag = "\[$name\]";
	    }

	    # SYNIDを獲得
	    my $childsyn_list = $tag ? &get_synid($child, $tag) :  &get_synid($child);
	    my $parentsyn_list = $tag ? &get_synid($parent, $tag) : &get_synid($parent);
	    if (&contradiction_check($parentsyn_list, $childsyn_list)) {
		if ($opt{log_merge}) {
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
			$key_p = (split(/\//, $key_p))[0];
			my $key_c = (split(/:/, $child))[0];
			$key_c = (split(/\//, $key_c))[0];
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

	if ($opt{log_merge}) {
	    close(LM);
	}

	close(ISA);
    }
}

#
# 反義語の読み込み
#

foreach my $file_type (@{$FILE{'antonym'}}) {
    if ($opt{$file_type}) {
	open(ANT, '<:encoding(utf-8)', $opt{$file_type}) or die;

	# 矛盾解消のログ
	if ($opt{log_merge}) {
	    open(LM, '>>:encoding(utf-8)', $opt{log_merge}) or die;    
	}

	while (<ANT>) {
	    chomp;

	    my $delimiter = defined $USER_DIC_FILENAME{$file_type} ? '\t' : '\s';
	    my ($word1, $word2) = split(/$delimiter/, $_);
	    $word1 = &SynGraph::h2z($word1) if defined $USER_DIC_FILENAME{$file_type};
	    $word2 = &SynGraph::h2z($word2) if defined $USER_DIC_FILENAME{$file_type};

	    # SYNIDを獲得
	    my $word1syn_list = &get_synid($word1);
	    my $word2syn_list = &get_synid($word2);
	    if (&contradiction_check($word1syn_list, $word2syn_list)) {
		if ($opt{log_merge}) {
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

	if ($opt{log_merge}) {
	    close(LM);
	}

	close(ANT);
    }
}


#
# 余った定義文は同義グループを作って登録
#
foreach my $midasi (keys %definition) {
    next if($def_delete{$midasi});

    # SYNIDの作成
    my $synid = 's' . $syn_number . ":" . (split(/:/, $midasi))[0];
    $syn_number++;

    my $midasi_key = $midasi . '[DIC]';
    my $def_key = $definition{$midasi} . '[定義文]';
    push (@{$syn_group{$synid}}, $midasi_key);
    push (@{$syn_group{$synid}}, $def_key);
    push (@{$syn_hash{$midasi}}, $synid);
    push (@{$syn_hash{$definition{$midasi}}}, $synid);
}

foreach my $file_type (@{$FILE{'similarphrase'}}) {
    if ($opt{$file_type}) {
	open(P, '<:encoding(utf-8)', $opt{$file_type}) or die;
	while (<P>) {
	    chomp;

	    my @phrases = split;

	    my $phrase1 = $phrases[0];
	    my $synid = 's' . $syn_number . ':' . &SynGraph::toupper($phrase1);
	    $syn_number++;

	    for my $phrase (@phrases) {
		my $tmp_phrase = &SynGraph::toupper($phrase) . '[同義句]';

		push (@{$syn_group{$synid}}, $tmp_phrase);
	    }
	}
	close P;
    }
}

# 属する語が1語しかないグループのSynIDから、「s(数字):」を削除
my %one_word_sid;
foreach my $synid (keys %syn_group) {
    my %definition_check;

    if (scalar @{$syn_group{$synid}} == 1) {
	# $synidが代表表記のもの（すなわち1語）
	if ($synid =~ /\//) {
	    # 「s(数字):」を除いたもの
	    my $newid;
	    ($newid = $synid) =~ s/^s\d+://;
	    $one_word_sid{$synid} = $newid;

	    @{$syn_group{$newid}} = @{$syn_group{$synid}};
	    delete $syn_group{$synid};
	}
    }
}

# 上位語
foreach my $synid (keys %relation_parent) {
    my @parents;
    for my $parent (split('\|', $relation_parent{$synid})) {
	# s14914:考えを引き出す,1
	my ($parent_synid, $num) = split(',', $parent);

	# 更新する
	if (defined $one_word_sid{$parent_synid}) {
	    $parent_synid = $one_word_sid{$parent_synid};
	}
	push @parents, "$parent_synid,$num";
    }
    my $newstring = join('|', @parents);

    if (defined $one_word_sid{$synid}) {
	$relation_parent{$one_word_sid{$synid}} = $newstring;
	delete $relation_parent{$synid};
    }
    else {
	$relation_parent{$synid} = $newstring;
    }
}

if ($option{log}) {
    # 下位語
    foreach my $synid (keys %relation_child) {
	my @children;
	for my $child (split('\|', $relation_child{$synid})) {

	    my $child_new;
	    # 更新する
	    if (defined $one_word_sid{$child}) {
		$child_new = $one_word_sid{$child};
	    }
	    else {
		$child_new = $child;
	    }
	    push @children, $child_new;
	}
	my $newstring = join('|', @children);

	if (defined $one_word_sid{$synid}) {
	    $relation_child{$one_word_sid{$synid}} = $newstring;
	    delete $relation_child{$synid};
	}
	else {
	    $relation_child{$synid} = $newstring;
	}
    }
}

# 反義語
foreach my $synid (keys %antonym) {
    my @antonyms;
    for my $antonym (split('\|', $antonym{$synid})) {

	my $new_parent_synid;
	# 更新する
	if (defined $one_word_sid{$antonym}) {
	    $antonym = $one_word_sid{$antonym};
	}
	push @antonyms, $antonym;
    }
    my $newstring = join('|', @antonyms);

    if (defined $one_word_sid{$synid}) {
	$antonym{$one_word_sid{$synid}} = $newstring;
	delete $antonym{$synid};
    }
    else {
	$antonym{$synid} = $newstring;
    }
}

#
# 同義グループをファイルに書き出す
#
if ($opt{convert_file}) {
    open(CF, '>:encoding(utf-8)', $opt{convert_file}) or die;    

    foreach my $synid (keys %syn_group) {
	my %check; # 曖昧性のある語の展開をチェック
	my %definition_check;
	foreach my $expression (@{$syn_group{$synid}}) {

	    # タグを取る
	    my $tag = $1 if $expression =~ s/\[(.+?)\]$//g;

	    # 定義文の重複を除く
	    if ($tag eq '定義文') {
		next if defined $definition_check{$expression};
		$definition_check{$expression} = 1;
	    }

	    # :1/1:1/1:1/1を取る
	    ($expression, my $word_id) = split(/:/, $expression, 2);
	    $word_id = ":$word_id" if $word_id;

	    next unless $expression;

            # 出力
            print CF "# S-ID:$synid,$expression$word_id\[$tag\]\n";
            print CF "$expression\n";
            
	    # 同義グループ情報
	    # $synid = 's517:趣/おもむき'
	    my $key_num = (split(/:/, $synid))[0];
	    $synnum{$key_num} = $synid;
#	    if ($tag eq 'DIC' || $tag eq 'Wikipedia') {
	    if ($word_id) {
		$expression .= "$word_id" . "[$tag]";
	    }
	    else { # '定義文''Web'
		$expression .= "[$tag]";
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
    open(LOG, '>:encoding(utf-8)', $opt{conv_log}) or die;
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
&SynGraph::store_cdb("$opt{syndbdir_cgi}/syndb.cdb", \%syndb);

#
# 同義グループ番号の保存（CGI用）
#
&SynGraph::store_cdb("$opt{syndbdir_cgi}/synnumber.cdb", \%synnum);

#
# 下位・上位関係？の保存（CGI用）
#
&SynGraph::store_cdb("$opt{syndbdir_cgi}/synchild.cdb", \%relation_child);

#
# 上位下位関係のログ保存（CGI用）
#
&SynGraph::store_cdb("$opt{syndbdir_cgi}/log_isa.cdb", \%log_isa);

#
# 反義関係のログ保存（CGI用）
#
&SynGraph::store_cdb("$opt{syndbdir_cgi}/log_antonym.cdb", \%log_antonym);

print STDERR scalar(localtime), "辞書のコンバート終了\n";

#
# SYNIDを取得、なければ同義グループを作る
#
sub get_synid {
    my ($word, $type) = @_;

    # 同義グループにある場合はそのSYNIDを返す
    if (defined $syn_hash{$word}) {
        return $syn_hash{$word};
    }
    # 「名称」はないが「名称:1/1:1/1」がある場合
    elsif (defined $syn_hash{"$word:1/1:1/1"}) {
	return $syn_hash{"$word:1/1:1/1"};
    }
    else {
        # SYNIDを振る
	my $synid = 's' . $syn_number . ":" . (split(/:/, $word))[0];
	$syn_number++;
	
        # グループに登録
	$type = '[DIC]' unless $type; # defaultは[DIC]
	my $word_key = $word . $type;
	push (@{$syn_group{$synid}}, $word_key);
        push (@{$syn_hash{$word}}, $synid);

        # 定義文があるとき
	my @log;
        if ($definition{$word}) {
	    my $def_key = $definition{$word} . '[定義文]';
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

# ユーザ辞書を読む
sub read_dic_user_dir {
    for my $file (glob "$opt{dic_user_dir}/*.txt") {
	# synonym_user, isa_user など 
	my $basename = basename($file, '.txt');
	my ($type, $name) = split('_', $basename);

	if (!defined $FILE{$type}) {
	    print STDERR "unknown type: $type\n";
	    next;
	}
	push @{$FILE{$type}}, $basename;
	$opt{$basename} = $file;
	$USER_DIC_FILENAME{$basename} = 1;
    }
}
