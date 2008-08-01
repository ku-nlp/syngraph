package SynGraph;

# $Id$

use utf8;
use strict;
use Encode;
use KNP;
use Dumpvalue;
use BerkeleyDB;
use Storable qw(freeze thaw);
use MLDBM qw(BerkeleyDB::Hash Storable);
use CDB_File;
use Constant;

#
# 定数
#

# 同義語のペナルティ
my $synonym_penalty = 0.99;
# 上位・下位のペナルティ
my $relation_penalty = 0.7;
# 反義語のペナルティ
my $antonym_penalty = 0.8;

# 素性の違いによるペナルティ
our $penalty = {fuzoku => 1.0,     # 付属語
		case => 0.3,       # 格
		kanou => 0.8,      # 可能表現
		sonnkei => 1,      # 尊敬表現
		ukemi => 0.3,      # 受身表現
		shieki => 0.3,     # 使役表現
		negation => 0.3,   # 否定
		semicontentword => 0.8 # 準内容語
	    };  

# ノード登録のしきい値
my $regnode_threshold = 0.5;


# 無視する単語のリスト(IREX用)
# 代表表記が変更されたので、このままではマッチしない
my @stop_words;
@stop_words = qw(記事 関する 述べる 含める 探す 場合 含む 報道 言及 関連 議論 つく 具体 的だ 良い もの 物);



#
# コンストラクタ
#
sub new {
    my ($this, $syndbdir, $knp_option, $option) = @_;

    # knp option
    my @knpoption_array = ('-tab');
    push @knpoption_array, '-postprocess' if $knp_option->{postprocess};
    push @knpoption_array, '-copula' if $knp_option->{copula};
    push @knpoption_array, '-dpnd' if $knp_option->{no_case};
    my $knpoptions = join(' ', @knpoption_array);
    
    my %knp_pm_args = ( -Option => $knpoptions );

    # CGI用
    $knp_pm_args{'-Command'} = $knp_option->{knpcommand} if defined $knp_option->{knpcommand};
    $knp_pm_args{'-Rcfile'} = $knp_option->{knprcfile} if defined $knp_option->{knprcfile};
    $knp_pm_args{'-JumanCommand'} = $knp_option->{jumancommand} if defined $knp_option->{jumancommand};
    $knp_pm_args{'-JumanRcfile'} = $knp_option->{jumanrcfile} if defined $knp_option->{jumanrcfile};

    # version
    my $version;
    my $version_file = "$Constant::SynGraphBaseDir/VERSION";
    if (-e $version_file) {
	open F, "< $version_file" or die;
	$version = <F>;
	chomp $version;
	close F;
    }

    $this = {
        mode       => '',
        regnode    => '',
	matching   => '',
        syndata    => {},
        syndatacache    => {},
        synhead    => {},
        synsort    => {},
        synheadcache    => {},
        synparent  => {},
        synparentcache  => {},
        synchild  => {},
        synantonym  => {},
        synantonymcache  => {},
        syndb  => {},
        synnumber  => {},
	log_isa => {},
	log_antonym => {},
        filehandle => undef,
        db_type    => '',
        db_name    => '',
        db_table   => '',
        dbh        => undef,
        sth        => undef,
        st_head    => {},
        st_data    => [],
        tm_sg      => {},
	knp        => new KNP(%knp_pm_args),
	# by NICT
	fast       => $option->{fast},
	db_on_memory => $option->{db_on_memory},
	version => $version
    };
    
    bless $this;

    if (defined $syndbdir and $syndbdir ne "") { # by NICT
	if ($option->{db_on_memory}) {
	    $this->retrieve_syndb("$syndbdir/syndata.mldbm", "$syndbdir/synhead.cdb", "$syndbdir/synparent.cdb", "$syndbdir/synantonym.cdb");
	}
	else {
	    # 類義表現DBをtie
	    $this->tie_syndb("$syndbdir/syndata.mldbm", "$syndbdir/synhead.cdb", "$syndbdir/synparent.cdb", "$syndbdir/synantonym.cdb");
	}

	# CGI用
	if (defined $option->{cgi}) {
	    $this->tie_forsyndbcheck("$syndbdir/syndb.cdb", "$syndbdir/synnumber.cdb", "$syndbdir/synchild.cdb",
				     "$syndbdir/log_isa.cdb", "$syndbdir/log_antonym.cdb");
	}
    }
    
    return $this;
}



################################################################################
#                                                                              #
#                                SYNGRAPH 関係                                 #
#                                                                              #
################################################################################

#
# SYNGRAPHを作成
#
sub make_sg {
    my ($this, $input, $ref, $sid, $regnode_option, $option) = @_;

    # 入力がKNP結果の場合
    if (ref $input eq 'KNP::Result') {
        # 木を作る
        $this->make_tree($input, $ref, $option);
    }
    # 入力がXMLデータの場合(MT用)
    elsif (ref $input eq 'HASH' or $input =~ /^\s*<i_data/) {
        $this->_read_xml($input, $ref, $sid);
    }
    # それ以外はテキストデータとして処理する
    else {
        # パースする
        my $knp_result = $this->{knp}->parse($input);
        $knp_result->set_id($sid);
        # 木を作る
        $this->make_tree($knp_result, $ref, $option);
    }

    # 各BPにSYNノードを付けていってSYNGRAPHを作る
    if (!$option->{no_syn_id} && $ref->{$sid}) {
	for (my $bp_num = 0; $bp_num < @{$ref->{$sid}}; $bp_num++) {
	    $this->make_bp($ref, $sid, $bp_num, $regnode_option, $option); 
	}
    }
}


#
# 初期SYNGRAPHを作成
#
sub make_tree {
    my ($this, $knp_result, $tree_ref, $option) = @_;
    my $sid = $knp_result->id;

    # KNP.pmのmake_ssを使う
    if ($option->{use_make_ss}) {
	my $ss = $knp_result->make_ss;

	Dumpvalue->new->dumpValue($ss) if $option->{debug};
    }

    my @keywords = $this->_get_keywords($knp_result, $option);

    return if (@keywords == 0);

    for (my $bp_num = 0; $bp_num < @keywords; $bp_num++) {
        # 語の重み
        my $weight = 1;
        # IREX用ストップワード
        if ($this->{mode} =~ /irex/) {
            my $key = $keywords[$bp_num][0]->{name};
            $weight = 0 if (grep($key eq $_, @stop_words));
        }
        foreach my $node (@{$keywords[$bp_num]}) {
	    
	    # NODEのLOG作成
 	    my $log;
	    if ($option->{log}) {
		$log = $this->make_basicnode_log($node);
	    }

	    foreach my $type ('kakari_type', 'level', 'midasi') {
		$tree_ref->{$sid}[$bp_num]{$type} = $node->{$type} if $node->{$type};
	    }

	    $tree_ref->{$sid}[$bp_num]{parentbp} = $node->{parent} if $node->{parent};

	    $tree_ref->{$sid}[$bp_num]{fstring} = $node->{fstring} if $option->{store_fstring};

	    # SYNGRAPHに登録
            $this->_regnode({ref         => $tree_ref,
                             sid         => $sid,
                             bp          => $bp_num,
                             id          => $node->{name},
			     log         => $log,
                             fuzoku      => $node->{fuzoku},
                             childbp     => $node->{child},
			     case        => $node->{case},
                             kanou       => $node->{kanou},
			     sonnkei     => $node->{sonnkei},
                             ukemi       => $node->{ukemi},
			     shieki      => $node->{shieki},
			     negation    => $node->{negation},
                             score       => $node->{score},
                             weight      => $weight});
        }
    }
}


#
# BPにSYNノードを付与する
#
sub make_bp {
    my ($this, $ref, $sid, $bp, $regnode_option, $option) = @_;
    my %synnode_check;

    # 各SYNノードをチェック
    foreach my $node (@{$ref->{$sid}[$bp]{nodes}}) {
        next if ($node->{weight} == 0);

	# キャッシュしておく
 	if (!defined $this->{synheadcache}{$node->{id}}) {
	    if ($this->{mode} eq 'repeat') { # コンパイル時
		$this->{synheadcache}{$node->{id}} = $this->{synhead}{$node->{id}};
	    }
	    else {
		$this->{synheadcache}{$node->{id}} = $this->GetValue($this->{synhead}{$node->{id}});
	    }
	}

        if ($node->{id} and $this->{synheadcache}{$node->{id}}) {
            foreach my $mid (split(/\|/, $this->{synheadcache}{$node->{id}})) {
                # SYNIDが同じものは調べない
                my $synid1 = (split(/,/, $sid))[0];
                my $synid2 = (split(/,/, $mid))[0];
                next if ($synid1 eq $synid2);

		# キャッシュしておく
 		if (!defined $this->{syndatacache}{$mid}) {
		    $this->{syndatacache}{$mid} = $this->{syndata}{$mid};
 		}
		defined $synnode_check{$mid} ? next : ($synnode_check{$mid} = 1);

		my $headbp = @{$this->{syndatacache}{$mid}} - 1;

 		# synidがマッチするか調べる(付属語・素性などは考慮しない)
		my ($result_rough, $match_verbose) = $this->syngraph_matching_rough($ref->{$sid}, $bp, $this->{syndatacache}{$mid}, $headbp);
		next if $result_rough == 0;

		# 付属語・素性などを考慮してSynGraphマッチング
		# マッチする場合は新たに付与するnodeを得る
		my ($result, $newnode) = $this->syngraph_matching_and_get_newnode('syn', $ref->{$sid}, $bp, $this->{syndatacache}{$mid}, $headbp, $match_verbose);
		next if ($result == 0);

		# NODEのLOG
		my $log;
		if ($option->{log}) {
		    $log = $this->make_synnode_log($ref->{$sid}, $this->{syndatacache}{$mid}, $mid, $match_verbose);
		}

		$this->_regnode({ref            => $ref,
				 sid            => $sid,
				 bp             => $bp,
				 id             => $synid2,
				 log            => $log,
				 fuzoku         => $newnode->{fuzoku},
				 matchbp        => $newnode->{matchbp},
				 childbp        => $newnode->{childbp},
				 case           => $newnode->{case},
				 kanou          => $newnode->{kanou},
				 sonnkei        => $newnode->{sonnkei},
				 ukemi          => $newnode->{ukemi},
				 shieki         => $newnode->{shieki},
				 negation       => $newnode->{negation},
				 score          => $newnode->{score} * $synonym_penalty,
				 weight         => $newnode->{weight},
				 relation       => $newnode->{relation},
				 antonym        => $newnode->{antonym},
				 regnode_option => $regnode_option});
            }
        }
    }
    
    # キャッシュをクリア
    if ($option->{clear_cache}) {
	$this->{synheadcache} = {};
	$this->{syndatacache} = {};
	$this->{synparentcache} = {};
	$this->{synantonymcache} = {};
    }
}



#
# BPにIDを付与する (部分木用)
#
sub st_make_bp {
    my ($this, $ref, $sid, $bp, $max_tm_num, $option, $matching_option) = @_;

    # ノードはどんどん追加されるので、元のノードを退避してforeachをまわす
    # こうしないと、追加されたノードまで新たなキーとしてしまう
    my @node_list = @{$ref->{$sid}[$bp]{nodes}};
    my %stid_tmp;
    foreach my $node (@node_list) {
        next if ($node->{weight} == 0);

	my %count_pattern;
        if ($node->{id}) {
	    my @head_list;
	    push(@head_list, @{$this->{st_head}{$node->{id}}}) if ($this->{st_head}{$node->{id}});

	    # 翻訳時のみ、子がある場合は、"子->親"のキーも探索
	    if ($option->{mt_trans}) {
		foreach my $c (keys %{$node->{childbp}}) {
		    foreach my $child_node (@{$ref->{$sid}[$c]{nodes}}) {
			next if ($node->{not_synnode});
			my $head_key = $child_node->{id}."->".$node->{id};
			push(@head_list, @{$this->{st_head}{$head_key}}) if ($this->{st_head}{$head_key});
		    }
		}
	    }
	    
            foreach my $stid (@head_list) {
		my $st_data = $this->get_st_data_value($this->{st_data}, $stid);
		unless ($st_data) {
		    print STDERR "TM: $stid Not Found\n";
		    next;
		}
                my $headbp = $st_data->{head};
                my $tmid = $st_data->{tmid};
                my %body;
                map {$body{$_} = 1} split(" ", $st_data->{body});

		# すでにチェックしたTMは再度チェックしない
		if ($stid_tmp{$stid}) {
		    next;
		} else {
		    $stid_tmp{$stid} = 1;
		}
		
		# MTのアラインメント時は、先に英語列で評価
		my $mt_end_flag = 0;
		if ($option->{mt_align}) {
		    $mt_end_flag = 1;
		    foreach my $estr (@{$st_data->{mvalue}}) {
			if (index($option->{mt_align}, $estr) >= 0) {
			    $mt_end_flag = 0;
			    last;
			}
		    }
		}
		next if ($mt_end_flag);

                # TMのSYNGRAPHを取得
                unless ($this->{tm_sg}{$tmid}) {
                    $this->db_retrieve($this->{tm_sg}, [$tmid]);
                }
                
 		# synidがマッチするか調べる(付属語・素性などは考慮しない)
		my ($result_rough, $match_verbose) = $this->syngraph_matching_rough($ref->{$sid}, $bp, $this->{tm_sg}{$tmid}, $headbp,
							    \%body, $matching_option);
		if ($result_rough == 0) {
		    delete $this->{tm_sg}{$tmid};
		    next;
		}

		# 付属語・素性などを考慮してSynGraphマッチング
		# マッチする場合は新たに付与するnodeを得る
		my ($result, $newnode) = $this->syngraph_matching_and_get_newnode('MT', $ref->{$sid}, $bp, $this->{tm_sg}{$tmid}, $headbp, $match_verbose, $option);
		if ($result == 0) {
		    delete $this->{tm_sg}{$tmid};
		    next;
		}

		# 入力の文節番号集合
		my @s_body;
		foreach my $i (@{$newnode->{match}}) {
		    push(@s_body, @{$i->{graph_1}});
		}
		my $s_pattern = join(" ", sort(@s_body));

		# by NICT
		# NOTE:
		#   It's sometimes very slow to never break this loop.
		#   So we make the loop break by one of counters for demo,
		#   but we cannot pick up the whole variations for s_patterns.
		# next if ($max_tm_num != 0 && $count_pattern{$s_pattern} >= $max_tm_num);
		if ($max_tm_num != 0 && $count_pattern{$s_pattern} >= $max_tm_num) {
		    if(defined($this->{fast}) && $this->{fast} > 0) {
			last;
		    } else {
			next ;
		    }
		}
		$count_pattern{$s_pattern}++;
		
		# アライメントのLOG
		my $log;
		if ($option->{log}) {
		    $log = $this->st_make_log($ref->{$sid}, $this->{tm_sg}{$tmid}, $tmid, $match_verbose);
		}

		delete $this->{tm_sg}{$tmid} if ($option->{clear_cache});

		my $newid =
		    # シソーラス、反義語データベースは使用しない
		    $this->_regnode({ref            => $ref,
				     sid            => $sid,
				     bp             => $bp,
				     id             => $stid,
				     log            => $log,
				     fuzoku         => $newnode->{fuzoku},
				     matchbp        => $newnode->{matchbp},
				     childbp        => $newnode->{childbp},
				     case           => $newnode->{case},
				     kanou          => $newnode->{kanou},
				     sonnkei        => $newnode->{sonnkei},
				     ukemi          => $newnode->{ukemi},
				     shieki         => $newnode->{shieki},
				     negation       => $newnode->{negation},
				     score          => $newnode->{score} * $synonym_penalty,
				     weight         => $newnode->{weight},
				     not_synnode    => 1
				 });

		$newid->{matchid}   = $newnode->{matchid} if ($newid);
		$newid->{match}     = $newnode->{match} if ($newid);
		$newid->{matchpair} = $newnode->{matchpair} if ($newid);
		$newid->{hypo_num}  = $node->{hypo_num} if ($newid && $node->{hypo_num});
	    }
	}
    }
    # キャッシュをクリア
    if ($option->{clear_cache}) {
	$this->{synheadcache} = {};
	$this->{syndatacache} = {};
	$this->{synparentcache} = {};
	$this->{synantonymcache} = {};
    }
}


#
# IDが部分木に含まれているかどうかを判定
#
sub st_check {
    my ($node, $st_body) = @_;
    my @cm_bp;
    
    if ($node->{matchbp}) {
        @cm_bp = keys %{$node->{matchbp}};
    }

    foreach my $cm (@cm_bp) {
        return 0 unless ($st_body->{$cm});
    }
    return 1;
}


#
# KNP結果からキーワードを取り出す
#
sub _get_keywords {
    my ($this, $knp_result, $option) = @_;
    my @keywords;

    # BP単位
    my $child = {};
    my $case = {};

    foreach my $tag ($knp_result->tag) {
        my @alt;
        my $nodename;
        my $nodename_num; # 数字汎化用ID
        my $fuzoku;
	my $midasi;
	my $parent;
	my $kakari_type;
        my $negation;
	my $level;
	my $kanou;
	my $sonnkei;
	my $ukemi;
	my $shieki;

        # 子供 child->{親のid}{子のid}
        $child->{$tag->{parent}{id}}{$tag->{id}} = 1 if ($tag->{parent});

	# 親
	if ($tag->{parent}) {
	    $parent = $tag->{parent}{id};
	}
	else {
	    $parent = -1;
	}

	# 親への係り方
	$kakari_type = $tag->dpndtype if ($tag->dpndtype);

	# 格 case->{係り元のid}{係り先のid} = '〜格'
	# <格解析結果:書く/かく:動1:ガ/C/彼/0/0/?;ヲ/N/本/2/0/?;ニ/U/-/-/-/-;ト/U/-/-/-/-;デ/U/-/-/-/-;カラ/U/-/-/-/-;マデ/U/-/-/-/-;φ/U/-/-/-/-;時間/U/-/-/-/-;外の関係/U/-/-/-/-;ノ/U/-/-/-/-;ニツク/U/-/-/-/->
	if($tag->{fstring} =~ /\<格解析結果:(.+?):(.+?):([PC]\d+:)?(.+?)\>/) {
	    foreach my $str (split(/;/, $4)){
		my ($case_tmp, $type, $hyouki, $tid, $sid) = split(/\//, $str);

		$case->{$tid}{$tag->{id}} = $case_tmp if ($tid ne '-');
	    }
	}

        # 可能表現
        $kanou = 1 if ($tag->{fstring} =~ /<可能表現>/);

        # 尊敬表現
        $sonnkei = 1 if ($tag->{fstring} =~ /<敬語:尊敬表現>/);

	# 否定表現
        $negation = 1 if ($tag->{fstring} =~ /<否定表現>/);

	# 態
	if ($tag->{fstring} =~ /<態:([^\s\/\">]+)/) {
	    foreach (split(/\|/,$1)) {
		$kanou   = 1 if ($_ =~ /可能/);
		$sonnkei = 1 if ($_ =~ /尊敬/);
		$shieki  = 1 if ($_ =~ /使役/);
		$ukemi   = 1 if ($_ =~ /受動/);
		last;
	    }
	}
	
	# 節のレベル
	if ($tag->{fstring} =~ /<レベル:([^\s\/\">]+)/) {
	    $level .= $1;
	}

	my @mrphs = $tag->mrph;
	for (my $i = 0; $i < @mrphs; $i++) {
	    my $mrph = $mrphs[$i];

            next if ($mrph->{hinsi} eq '特殊' and $mrph->{bunrui} ne '記号');

            # 意味有
            if ($mrph->{fstring} =~ /<準?内容語>/ ||
		# -copulaのとき、判定詞には<意味有>がないので、特別処理
		($mrph->{fstring} =~ /<後処理\-基本句始>/ && $mrph->hinsi eq "判定詞")) {

		my $nodename_str = &get_nodename_str($mrph);

		# 数詞の汎化
		if ($mrph->{hinsi} eq "名詞" && $mrph->{bunrui} eq "数詞" &&
		    $mrph->{genkei} !~ /^(何|幾|数|なん|いく|すう)$/) {
		    $nodename .= !$nodename ? "$nodename_str" : "+$nodename_str";
		    $nodename_num .= !$nodename_num ? "<num>" : "+<num>";
		} else {
		    $nodename .= !$nodename ? "$nodename_str" : "+$nodename_str";
		    $nodename_num .= !$nodename_num ? "$nodename_str" : "+$nodename_str";
		}

		push @alt, &get_alt($mrph, $tag);

		# 次の形態素が準内容語(自分は内容語)
		# カウンタは除く
		if ($option->{regist_exclude_semi_contentword} && $mrphs[$i]->fstring =~ /<内容語>/ &&
		    defined $mrphs[$i + 1] && $mrphs[$i + 1]->fstring =~ /<準内容語>/ && $mrphs[$i + 1]->fstring !~ /<カウンタ>/) {
		    push @alt, { name => &get_nodename_str($mrph), score => $penalty->{semicontentword} };
		}
            }
            elsif ($mrph->{hinsi} eq '接頭辞') {
		# 接頭辞は無視
	    }
	    elsif (($mrph->{hinsi} eq '接尾辞' and $mrph->{genkei} eq 'ない') or
                   ($mrph->{hinsi} eq '助動詞' and $mrph->{genkei} eq 'ぬ')) {
		# ない、ぬは否定表現
	    }
	    else {
                # 代表表記
                if ($mrph->{fstring} =~ /<代表表記:([^\s\/\">]+)/) {
                    $fuzoku .= $1;
                }
                else {
                    $fuzoku .= $mrph->{genkei};
                }
            }

	    if ($mrph->{midasi}){
		$midasi .= $mrph->{midasi};
	    }
        }

	# 'name' => '最寄り/もより'
	# 'fuzoku' => 'の'
	# 'midasi' => '最寄りの'
	# 'parent' => 1
	# 'kakari_type' => 'D'
	
	# 'name' => '駅/えき'
	# 'fuzoku' => undef
	# 'midasi' => '駅'
	# 'level' => 'C'
	# 'parent' => '-1'
	# 'child' => HASH(0x8f129a4)
	#    0 => 1
	# 'kakari_type' => 'D'

        # 登録
	my %tmp;
	$tmp{name}        = $nodename;
	$tmp{fuzoku}      = $fuzoku;
	$tmp{midasi}      = $midasi;
	$tmp{kanou}       = $kanou if ($kanou);
	$tmp{sonnkei}     = $sonnkei if ($sonnkei);
	$tmp{ukemi}       = $ukemi if ($ukemi);
	$tmp{shieki}      = $shieki if ($shieki);
	$tmp{negation}    = $negation if ($negation);
	$tmp{level}       = $level if ($level);
	$tmp{parent}      = $parent if ($parent);
	$tmp{child}       = $child->{$tag->{id}} if ($child->{$tag->{id}});
	$tmp{kakari_type} = $kakari_type if ($kakari_type);
	$tmp{score} = 1;

	# 格情報登録
	if ($child->{$tag->{id}}) {
	    foreach my $childbp (keys %{$child->{$tag->{id}}}) {
		if ($case->{$childbp}{$tag->{id}}) {
		    foreach my $parentnode (@{$keywords[$childbp]}) {
			$parentnode->{case} = $case->{$childbp}{$tag->{id}};
		    }
		}
	    }
	}

	# fstring
	if ($option->{store_fstring}) {
	    $tmp{fstring} = $tag->fstring;
	}

	push(@{$keywords[$tag->{id}]}, \%tmp);
	
	# ALTの処理(意味有が1形態素と仮定)
	foreach my $alt (@alt) {
	    # 表記が同じものは無視
	    next if (grep($alt->{name} eq $_->{name}, @{$keywords[$tag->{id}]}));
	    # 登録
	    my %tmp2 = %tmp;
	    $tmp2{name} = $alt->{name};
	    $tmp2{score} = $alt->{score};
	    push(@{$keywords[$tag->{id}]}, \%tmp2);
	}
	
	# 数詞を汎化したidを登録
	if ($option->{num_generalize} && $nodename_num =~ /<num>/) {
	    my %tmp2 = %tmp;
	    $tmp2{name} = $nodename_num;
	    push(@{$keywords[$tag->{id}]}, \%tmp2);
	}
    }
    
    return @keywords;
}

sub get_nodename_str {
    my ($mrph) = @_;

    my $nodename_str;
    # 可能動詞であれば戻す
    if ($mrph->fstring =~ /<可能動詞:([^\s\">]+)/) {
	$nodename_str = $1;
    }
    # 尊敬動詞であれば戻す
    elsif ($mrph->fstring =~ /<尊敬動詞:([^\s\">]+)/) {
	$nodename_str = $1;
    }
    # 代表表記
    elsif ($mrph->fstring =~ /<代表表記:([^\s\">]+)/) {
	$nodename_str = $1;
    }
    # 擬似代表表記
    elsif ($mrph->fstring =~ /<疑似代表表記:([^\s\">]+)/) {
	$nodename_str = $1;
    }
    else {
	$nodename_str = $mrph->genkei;
    }
    return $nodename_str;
}

sub get_alt {
    my ($mrph, $tag) = @_;

    my @alt;

    my $score = 1; # ここで得られるものはすべてスコア1

    # ALT<ALT-あえる-あえる-あえる-2-0-1-2-"ドメイン:料理・食事 代表表記:和える/あえる">
    # 用言/名詞曖昧性解消されてない場合、ALTの情報からSynノードを作る
    unless ($mrph->fstring =~ /<(?:名詞|用言)曖昧性解消>/) {
	if (my @tmp = ($mrph->{fstring} =~ /(<ALT.+?>)/g)) {
	    foreach (@tmp){
		# 可能動詞であれば戻す
		if ($_ =~ /可能動詞:([^\s\">]+)/) {
		    push @alt, { name => $1, score => $score };
		}
		# 尊敬動詞であれば戻す
		elsif ($_ =~ /尊敬動詞:([^\s\">]+)/) {
		    push @alt, { name => $1, score => $score };
		}
		# 代表表記
		elsif ($_ =~ /代表表記:([^\s\">]+)/){
		    push @alt, { name => $1, score => $score };
		}
	    }
	}
    }

    # 品詞変更<品詞変更:動き-うごき-動く-2-0-2-8-"代表表記:動く/うごく">
    # 「歩き方」＝「歩く方法」
    # ただし利用は文末以外
    if ($tag->{parent}) {
	while ($mrph->{fstring} =~ /(<品詞変更.+?>)/g) {
	    # 代表表記
	    if ($1 =~ /代表表記:([^\s\">]+)/){
		push @alt, { name => $1, score => $score };
	    }
	}
    }

    # 同義<同義:方法/ほうほう>
    while ($mrph->{fstring} =~ /(<同義.+?>)/g) {
	# 代表表記
	if ($1 =~ /同義:([^\s\">]+)/){
	    push @alt, { name => $1, score => $score };
	}
    }

    return @alt;
}

#
# IDを登録
#
sub _regnode {
    my ($this, $args_hash) = @_;
    my $ref                   = $args_hash->{ref};
    my $sid                   = $args_hash->{sid};
    my $bp                    = $args_hash->{bp};
    my $id                    = $args_hash->{id};
    my $log                   = $args_hash->{log};
    my $fuzoku                = $args_hash->{fuzoku};
    my $midasi                = $args_hash->{midasi};
    my $matchbp               = $args_hash->{matchbp};
    my $childbp               = $args_hash->{childbp};
    my $case                  = $args_hash->{case};
    my $kanou                 = $args_hash->{kanou};
    my $sonnkei               = $args_hash->{sonnkei};
    my $ukemi                 = $args_hash->{ukemi};
    my $shieki                = $args_hash->{shieki};
    my $negation              = $args_hash->{negation};
    my $score                 = $args_hash->{score};
    my $weight                = $args_hash->{weight};
    my $relation              = $args_hash->{relation};
    my $hypo_num              = $args_hash->{hypo_num};
    my $antonym               = $args_hash->{antonym};
    my $wnum                  = $args_hash->{wnum};
    my $regnode_option        = $args_hash->{regnode_option};
    my $not_synnode           = $args_hash->{not_synnode};

    # コンパイルでは完全に一致する部分にはIDを付与しない
    return if ($this->{mode} eq 'repeat' and $bp == @{$ref->{$sid}} - 1 and !$childbp);

    # スコアが小さいIDは登録しない
    # ただし、上位語を再帰的にはりつけるオプション(relation_recursive)の時はスコアチェックをしない
    if (($regnode_option->{relation_recursive} || !$regnode_option->{relation_recursive} && $score >= $regnode_threshold) or ($this->{mode} =~ /irex/ and $weight == 0)) {
        # 既にそのIDが登録されていないかチェック
        if ($ref->{$sid}[$bp]) {
            foreach my $i (@{$ref->{$sid}[$bp]{nodes}}) {
                if ($i->{id}        eq $id and
                    $i->{kanou}     == $kanou and
                    $i->{sonnkei}   == $sonnkei and
		    $i->{ukemi}     == $ukemi and
		    $i->{shieki}    == $shieki and
                    $i->{negation}  == $negation and
                    $i->{weight}    == $weight) {
                    if ($i->{score} < $score) {
                        $i->{score} = $score;
			$relation ? $i->{relation} = 1 : delete $i->{relation};
			$antonym ? $i->{antonym} = 1 : delete $i->{antonym};
                    }
                    return;
                }
		# ???
                return if ($id eq (split(/,/, $sid))[0]);
            }
        }

        my $newid = {};
        $newid->{id} = $id;
        $newid->{log} = $log if ($log);
        $newid->{fuzoku} = $fuzoku if ($fuzoku);
        if ($childbp) {
	    foreach my $c (keys %{$childbp}) {
		$newid->{childbp}{$c} = 1;
	    }
	}
	$newid->{case} = $case if ($case);
        if ($matchbp) {
            foreach my $m (keys %{$matchbp}) {
                $newid->{matchbp}{$m} = 1 if ($m != $bp);
            }
        }
        $newid->{kanou}    = $kanou if ($kanou);
        $newid->{sonnkei}  = $sonnkei if ($sonnkei);
	$newid->{ukemi}    = $ukemi if ($ukemi);
	$newid->{shieki}   = $shieki if ($shieki);
	$newid->{negation} = $negation if ($negation);
        $newid->{score}    = $score;
        $newid->{weight}   = $weight;
        $newid->{relation} = $relation if ($relation);
        $newid->{hypo_num} = $hypo_num if ($hypo_num);
        $newid->{wnum}     = $wnum if($wnum);
        $newid->{antonym}  = $antonym if ($antonym);
	$newid->{not_synnode} = $not_synnode if ($not_synnode);
        push(@{$ref->{$sid}[$bp]{nodes}}, $newid);

	# 上位IDがあれば登録(ただし上位語の上位語や、反義語の上位語は登録しない)
	# 上位語を再帰的にはりつけるオプション(relation_recursive)
	if ($regnode_option->{relation} and ($regnode_option->{relation_recursive} || (!$regnode_option->{relation_recursive} && $relation != 1)) and $antonym != 1 and !$not_synnode){

	    # キャッシュしておく
	    $this->{synparentcache}{$id} = $this->GetValue($this->{synparent}{$id}) if (!defined $this->{synparentcache}{$id});

	    if ($this->{synparentcache}{$id}) {
		foreach my $pid_num (split(/\|/, $this->{synparentcache}{$id})) {
		    my ($pid, $number) = split(/,/, $pid_num);

		    # 下位語数が $regnode_option->{hypocut_attachnode} より大きければ、SYNノードをはりつけない
		    next if ($regnode_option->{hypocut_attachnode} and $regnode_option->{hypocut_attachnode} < $number);
		    
		    # NODEのLOG
		    my $log;
		    if ($regnode_option->{log}) {
			$log = $this->make_relnode_log($newid, $pid, $this->{log_isa}, $midasi, 'parent');
		    }

		    $this->_regnode({ref            => $ref,
				     sid            => $sid,
				     bp             => $bp,
				     id             => $pid,
				     log            => $log,
				     fuzoku         => $fuzoku,
				     midasi         => $midasi,
				     matchbp        => $matchbp,
				     childbp        => $childbp,
				     case           => $case,
				     kanou          => $kanou,
				     sonnkei        => $sonnkei,
				     ukemi          => $ukemi,
				     shieki         => $shieki,
				     negation       => $negation,
				     score          => $score * $relation_penalty,
				     weight         => $weight,
				     regnode_option => $regnode_option,
				     relation       => 1,
				     hypo_num       => $number
				 });
		}
	    }
	}

	if ($regnode_option->{antonym} and !$not_synnode){
	    # キャッシュしておく
 	    if ($antonym != 1 and $relation != 1 && !defined $this->{synantonymcache}{$id}) {
 		$this->{synantonymcache}{$id} = $this->GetValue($this->{synantonym}{$id});
 	    }

	    # 反義語があれば登録（ただし、上位語の反義語や、反義語の反義語は登録しない。）
	    if ($this->{synantonymcache}{$id} and $antonym != 1 and $relation != 1) {
		foreach my $aid (split(/\|/, $this->{synantonymcache}{$id})) {
		    
		    # NODEのLOG
		    my $log;
		    if ($regnode_option->{log}) {
			$log = $this->make_relnode_log($newid, $aid, $this->{log_antonym}, $midasi, 'antonym');
		    }
		    
		    $this->_regnode({ref            => $ref,
				     sid            => $sid,
				     bp             => $bp,
				     id             => $aid,
				     log            => $log,
				     fuzoku         => $fuzoku,
				     midasi         => $midasi,
				     matchbp        => $matchbp,
				     childbp        => $childbp,
				     case           => $case,
				     kanou          => $kanou,
				     sonnkei        => $sonnkei,
				     ukemi          => $ukemi,
				     shieki         => $shieki,
				     negation       => $negation ^ 1,
				     score          => $score * $antonym_penalty,
				     weight         => $weight,
				     regnode_option => $regnode_option,
				     antonym        => 1});
		}
	    }
	}

        if ($this->{mode} eq 'repeat' and
            $newid->{id} and
            $bp == @{$ref->{$sid}} - 1) {
	    $this->{synhead}{$newid->{id}} .= $this->{synhead}{$newid->{id}} ? "|$sid" : $sid unless ($this->{synhead}{$newid->{id}} =~ /$sid/);
            $this->{regnode} = $sid;
        }

        return $newid;
    }
}



#
# synidがマッチするか調べる(付属語・素性などは考慮しない)
# (graph_1の部分とgraph_2の全体)
#
sub syngraph_matching_rough {
    my ($this, $graph_1, $nodebp_1, $graph_2, $nodebp_2, $body_hash, $matching_option) = @_;
    
    my $matchnode_score = 0;
    my $matchnode_1;
    my $matchnode_2;
    my $matchnode_index1;
    my $matchnode_index2;
    my %matchnode_unmatch_feature;
    my $matchnode_unmatch_num = scalar (keys %{$penalty}); # 初期値

    my $result = 0;
    my %match_verbose;

    # BP内でマッチするノードを探す
    my $node_index1 = -1;
    foreach my $node_1 (@{$graph_1->[$nodebp_1]{nodes}}) {
	$node_index1++;

	# スコアが低いものは調べない。
        next if ($node_1->{score} < $matchnode_score);

	my $node_index2 = -1;
        foreach my $node_2 (@{$graph_2->[$nodebp_2]{nodes}}) {
	    $node_index2++;
	    # ノード間のマッチを調べる。ただし、上位グループ、反義グループを介したマッチは行わない。
            if ((!defined $body_hash or &st_check($node_2, $body_hash))
		and $node_1->{id} eq $node_2->{id} 
		and (!($node_1->{relation} and $node_2->{relation}) or $matching_option->{coordinate_matching})
		and !($matching_option->{hypocut_matching} and (($node_1->{hypo_num} > $matching_option->{hypocut_matching}) or ($node_2->{hypo_num} > $matching_option->{hypocut_matching})))
		and !($node_1->{antonym} and $node_2->{antonym})) {

		# スコア
                my $score = $node_1->{score} * $node_2->{score};
		# スコアが低いものは調べない。同じスコアでも重みの小さなものは調べない。
		next if ($matchnode_score > $score 
			 or ($matchnode_score == $score 
			     and ($matchnode_1->{weight} + $matchnode_2->{weight} > $node_1->{weight} + $node_2->{weight})));
		
		# 付属語、素性の違いのチェック
		my %unmatch_feature;
		my $unmatch_num;
		foreach my $type (keys %{$penalty}) {
		    if ($node_1->{$type} ne $node_2->{$type}) {
			$unmatch_feature{$type} = {graph_1 =>$node_1->{$type}, graph_2 =>$node_2->{$type}};
			$unmatch_num++;
		    }
		}

		# スコアが大きいペアを採用。同じスコアならば重みの大きいものを、重みが同じならば素性の違いが少ないものを。
		if ($matchnode_score < $score
		    or ($matchnode_1->{weight} + $matchnode_2->{weight} < $node_1->{weight} + $node_2->{weight})
		    or ($matchnode_1->{weight} + $matchnode_2->{weight} == $node_1->{weight} + $node_2->{weight}
			and $matchnode_unmatch_num > $unmatch_num)) {
		    $matchnode_score = $score;
		    $matchnode_1 = $node_1;
		    $matchnode_2 = $node_2;
		    $matchnode_index1 = $node_index1;
		    $matchnode_index2 = $node_index2;
		    %matchnode_unmatch_feature = %unmatch_feature;
		    $matchnode_unmatch_num = $unmatch_num;
		}
	    }		    
	}
    }
    
    # BPがマッチしない
    if ($matchnode_score == 0){
	$match_verbose{$nodebp_2}{unmatch_reason} = 'no_matchnode';
	return (0, \%match_verbose);
    }
    
    # BPがマッチした
    # 対応する基本句番号
    my $matchbp_1 = join(',', ($matchnode_1->{matchbp} ? sort (keys %{$matchnode_1->{matchbp}}, $nodebp_1) : ($nodebp_1)));
    my $matchbp_2 = join(',', ($matchnode_2->{matchbp} ? sort (keys %{$matchnode_2->{matchbp}}, $nodebp_2) : ($nodebp_2)));
    $match_verbose{$nodebp_2}{matchbp1} = $matchbp_1;
    $match_verbose{$nodebp_2}{matchbp2} = $matchbp_2;
    # マッチしたノードの情報の居場所
    $match_verbose{$nodebp_2}{nodedata1} = "$nodebp_1-$matchnode_index1";
    $match_verbose{$nodebp_2}{nodedata2} = "$nodebp_2-$matchnode_index2";
    # マッチのスコア,素性の違い
    $match_verbose{$nodebp_2}{score} = $matchnode_score;
    foreach my $type (keys %matchnode_unmatch_feature) {
	$match_verbose{$nodebp_2}{unmatch_feature}{$type} = 1;
    }

    # $graph_2の検索対象となる子どもを取得
    my @childbp_2;
    if ($matchnode_2->{childbp}) {
	if (defined $body_hash) {
	    @childbp_2 = grep($body_hash->{$_}, sort keys %{$matchnode_2->{childbp}});
	}
	else {
	    @childbp_2 = keys %{$matchnode_2->{childbp}};
	}
    }

    # graph_2に子があれば
    if (@childbp_2 > 0) {

	# graph_1に子があれば
	if ($matchnode_1->{childbp}) {
	    my @childbp_1 = keys %{$matchnode_1->{childbp}};
	    my %child_1_check;
	    
	    # graph_1の子の数よりgraph_2の子の数の方が多い場合はマッチ失敗
	    if (@childbp_1 < @childbp_2) {
		$match_verbose{$nodebp_2}{unmatch_reason} = 'child_less';
		return (0, \%match_verbose);
	    }
	    
	    # graph_2の各子供にマッチするgraph_1の子供を見つける
	    foreach my $child_2 (@childbp_2) {
		my $match_flag = 0;

		foreach my $child_1 (@childbp_1) {
		    # すでにgraph_2他の子とマッチしたgraph_1の子はチェックしない
		    next if ($child_1_check{$child_1});
		    
		    # 子供同士のマッチング
		    my ($result_child, $match_verbose_child) = $this->syngraph_matching_rough($graph_1, $child_1, $graph_2, $child_2, $body_hash, $matching_option);
		    next if ($result_child == 0);
	
		    foreach my $nodebp (keys %{$match_verbose_child}) {
			$match_verbose{$nodebp} = $match_verbose_child->{$nodebp};
		    }

		    $child_1_check{$child_1} = 1;
		    $match_flag = 1;
		    last;
		}

		# マッチする子がなかったらマッチ失敗
		unless ($match_flag) {
		    $match_verbose{$nodebp_2}{unmatch_reason} = "child_unmatch:$graph_2->[$child_2]{midasi}";
		    return (0, \%match_verbose);
		}
	    }
	    return (1, \%match_verbose);
	}

	# graph_1に子がない場合はマッチ失敗
	else {
	    $match_verbose{$nodebp_2}{unmatch_reason} = 'child_less';
	    return (0, \%match_verbose);
	}
    }

    # graph_2に子がない
    else {
	$result = 1;
	return (1, \%match_verbose);
    }
}


# 付属語・素性などを考慮してSynGraphマッチング
# マッチする場合は新たに付与するnodeを得る
sub syngraph_matching_and_get_newnode {
    my ($this, $mode, $graph1, $headbp1, $graph2, $headbp2, $match_verbose, $option) = @_;
    my $newnode = {};
    my $score;
    my @match;
    my @child;

    my $result = 0;

    my $num;
    foreach my $matchkey (keys %{$match_verbose}) {

	# マッチしたノード情報のありか
	my ($bp1, $node_index1) = split(/-/, $match_verbose->{$matchkey}{nodedata1});
	my ($bp2, $node_index2) = split(/-/, $match_verbose->{$matchkey}{nodedata2});

	# ★headを早く見つけることで高速化可能★odani0529
	# headでの処理
	if ($headbp2 == $matchkey) {
	    
	    if ($mode eq 'syn') {
		if ($match_verbose->{$matchkey}{unmatch_feature}) {
		    # 新たなSYNノードとして貼り付けてよいかどうかをチェック(headに違いがありgraph_2に引き継ぎ不可)
		    # headの素性を引き継ぐ
		    foreach my $type (keys %{$match_verbose->{$matchkey}{unmatch_feature}}) {
			if ($type eq 'negation') {
			    $newnode->{$type} = 1;
			}
			else {
			    if ($graph2->[$bp2]{nodes}[$node_index2]{$type}) { # 引き継げない
				return 0;
			    }
			    else {
				$newnode->{$type} = $graph1->[$bp1]{nodes}[$node_index1]{$type};
			    }			    
			}
		    }
		}
	    }
	    elsif($mode eq 'MT') {
		if ($match_verbose->{$matchkey}{unmatch_feature}) {
		    # MTでアライメントをとるときはheadでの違いは否定以外はみない。
		    $newnode->{negation} = 1 if ($match_verbose->{$matchkey}{unmatch_feature}{negation});
		}

		# 付属語が異なり、かつ、$graph2の方にfuzokuがあれば、マッチさせない
		# 例: 「あり <=> あるとすれば」などをマッチさせない
		if (defined $match_verbose->{$matchkey}{unmatch_feature}{fuzoku} && $graph2->[$bp2]{nodes}[$node_index2]{fuzoku}) {
		    return 0;
		}
	    }
	}

	# その他での処理
	else {
	    # 素性の不一致ごとにスコアにペナルティをかける
	    if ($match_verbose->{$matchkey}{unmatch_feature}) {
		foreach my $type (keys %{$match_verbose->{$matchkey}{unmatch_feature}}) {
		    # 片一方にでも格がなければペナルティをかけない
		    if ($type eq 'case') {
			next if (!$graph1->[$bp1]{nodes}[$node_index1]{$type}
				 or !$graph2->[$bp2]{nodes}[$node_index2]{$type});
		    }
		    # 付属語が不一致があった場合はマッチさせないオプション
		    elsif ($type eq 'fuzoku' and defined $option->{force_match}{$type}) {
			return 0;
		    }
		    $match_verbose->{$matchkey}{score} *= $penalty->{$type};
		}
	    }
	}

	# スコア
	$score += $match_verbose->{$matchkey}{score};
	
	# マッチした基本句
	push (@match, split(/,/, $match_verbose->{$matchkey}{matchbp1}));

	# 関係フラグ
	$newnode->{relation} = 1 if ($graph1->[$bp1]{nodes}[$node_index1]{relation} or $graph2->[$bp2]{nodes}[$node_index2]{relation});
	$newnode->{antonym} = 1 if ($graph1->[$bp1]{nodes}[$node_index1]{antonym} or $graph2->[$bp2]{nodes}[$node_index2]{antonym});

	# MTのアライメント用
	if ($mode eq 'MT') {
	    my @match1 = split(/,/, $match_verbose->{$matchkey}{matchbp1});
	    my @match2 = split(/,/, $match_verbose->{$matchkey}{matchbp2});
	    push(@{$newnode->{match}}, {graph_1 => \@match1, graph_2 => \@match2});
	    push(@{$newnode->{matchpair}}, {graph_1 => $graph1->[$bp1]{midasi} , graph_2 => $graph2->[$bp2]{midasi}});
	    push(@{$newnode->{matchid}}, {graph_1 => $graph1->[$bp1]{nodes}[$node_index1]{id}, graph_2 => $graph2->[$bp2]{nodes}[$node_index2]{id}});
	}
    }

    # SYNノードのスコア
    my $num = (keys %{$match_verbose});
    $newnode->{score} = $score / $num;

    # SYNノードのその他の素性
    foreach my $matchbp1 (sort @match) {
	$newnode->{midasi} .= $graph1->[$matchbp1]{midasi};
	$newnode->{weight} += $graph1->[$matchbp1]{nodes}[0]{weight};
	if ($graph1->[$matchbp1]{nodes}[0]{childbp}) {
	    foreach my $childbp1 (keys %{$graph1->[$matchbp1]{nodes}[0]{childbp}}) {
		push (@child, $childbp1) unless grep($childbp1 eq $_, @match);
	    }
	}
	$newnode->{matchbp}{$matchbp1} = 1 unless $matchbp1 == $headbp1;
    }
    foreach my $childbp1 (@child) {
	$newnode->{childbp}{$childbp1} = 1;
    }

    return (1, $newnode);
}
    


################################################################################
#                                                                              #
#                        SYNGRAPHのtool関係                                    #
#                                                                              #
################################################################################

sub OutputSynFormat { 
    my ($this, $result, $regnode_option, $option) = @_;

    my $ret_string;
    my $syngraph = {};
    my $syngraph_string;

    # 入力をSynGraph化
    $syngraph->{graph} = {};
    $this->make_sg($result, $syngraph->{graph}, $result->id, $regnode_option, $option);
    Dumpvalue->new->dumpValue($syngraph->{graph}) if ($option->{debug});

    # SynGraphをformat化
    $syngraph_string = $this->format_syngraph($syngraph->{graph}{$result->id}, $option);

    # KNPとSYNGRAPHを併せて出力
    $ret_string = $result->comment;
    chomp $ret_string; # 改行をとる
    # version
    if (defined $this->{version}) {
	$ret_string .= " SynGraph:$this->{version}";
    }
    $ret_string .= "\n";

    my $bp = 0;
    foreach my $bnst ($result->bnst) {
	$ret_string .= '* ';
	$ret_string .= $bnst->{parent} ? $bnst->{parent}->{id} : -1;
	$ret_string .= "$bnst->{dpndtype} $bnst->{fstring}\n";

	foreach my $tag ($bnst->tag) {
	    # knp解析結果を出力
	    $ret_string .= '+ ';
	    $ret_string .= $tag->{parent} ? $tag->{parent}->{id} : -1;
	    $ret_string .= "$tag->{dpndtype} $tag->{fstring}\n";
	    foreach my $mrph ($tag->mrph) {
		$ret_string .= $mrph->spec;
	    }

	    # SYNGRPH情報の付与
	    $ret_string .= $syngraph_string->[$bp];
	    $bp++;
	}
    }
    $ret_string .= "EOS\n";

    return $ret_string;
}

# 入力全体の上位語を得る (舞浜駅 -> 駅)
sub GetHypernym {
    my ($this, $result, $regnode_option, $option) = @_;

    my $syngraph = {};
    my $syngraph_string;

    my $id = $result->id;
    # 入力をSynGraph化
    $syngraph->{graph} = {};
    $this->make_sg($result, $syngraph->{graph}, $id, $regnode_option, $option);

    my $sg = $syngraph->{graph}{$id};

    Dumpvalue->new->dumpValue($sg) if ($option->{debug});

    my $tagnum = scalar @{$sg};

    my @hypernym_ids;

    # 主辞のnode
    for my $node (@{$sg->[$tagnum - 1]{nodes}}) {
	# 上位語のみ
	next unless defined $node->{relation};

	# 全体をカバーするもののみ
	my $flag = 1;
	for (my $i = 0; $i < $tagnum - 1; $i++) {
	    unless (defined $node->{matchbp}{$i}) {
		$flag = 0;
		last;
	    }
	}

	if ($flag) {
	    push @hypernym_ids, $node->{id};
	}
    }

    # 曖昧性のないときだけ返す
    if (scalar @hypernym_ids == 1) {
	return $hypernym_ids[0];
    }
    else {
	return '';
    }
}

sub make_basicnode_log {
    my ($this, $node) = @_;
    my $log;
    
    my $rep;
    foreach (split(/\+/,$node->{name})) {
	$rep .= (split(/\//,$_))[0];
    }
    if ($rep ne $node->{midasi}) {
	$log = "log : $node->{midasi} = $rep\n";
	$log .= "extract : $node->{midasi} => $rep";
#		    my %tag = ('kanou' => '可能', 'sonnkei' => '尊敬', 'ukemi' => '受身', 'shieki' => '使役', 'negation' => '否定');
#		    foreach my $type ('case', keys %tag) {
#			if ($node->{$type}) {
#			    if ($type eq 'case') {
#				$log .= "<$node->{case}格>";
#			    }
#			    else {
#				$log .= "<$tag{$type}>";
#			    }
#			}
#		    }
	$log .= "\n";
    }

    return $log;
}

sub make_synnode_log {
    my ($this, $graph1, $graph2, $mid, $match_verbose) = @_;
    my $result;
    
    # synid, expression1, expression2
    my ($synid, $expression2) = split(/,/, $mid);
    my ($expression1) = $synid =~ /s\d+:([^\/]+)/;

    # expression_orig, loglog
    my $expression_orig;
    my $loglog;
    foreach (sort {$a <=> $b} keys %{$match_verbose}) {
	my ($bp1, $num1) = split(/-/, $match_verbose->{$_}{nodedata1});
	my ($bp2, $num2) = split(/-/, $match_verbose->{$_}{nodedata2});
	$expression_orig .= $graph1->[$bp1]{midasi};
	
	# マッチした表現からDBの中の表現まで
	my $tmp2;
	if ($graph2->[$bp2]{nodes}[$num1]{log}) {
	    my @array = split(/\n/, $graph2->[$bp2]{nodes}[$num2]{log});
	    for (my $num = @array - 1; $num > -1; $num--) {
		next if $array[$num] =~ /^log/;
		if ($array[$num] =~ s/^synonym :([^=]+)=([^\(]+)//) {
		    $tmp2 .=  "synonym :$2 = $1$array[$num]\n";
		}
		elsif ($array[$num] =~ s/^extract :([^=]+)=>(.+)//) {
		    $tmp2 .=  "extract :$2 <= $1$array[$num]\n";
		}
	    }
	}

	# 入力の表現からマッチした表現まで
	my $tmp1;
	if ($graph1->[$bp1]{nodes}[$num1]{log}) {
	    foreach (split(/\n/, $graph1->[$bp1]{nodes}[$num1]{log})) {
		next if $_ =~ /^log/;
		$tmp1 .= "$_\n";
	    }
	}

	# tmp1とtmp2のつなぎ（今後の課題）
# 	if ($tmp1 and $tmp2) {
# 	    my $tmp1last = (split(/\n/, $tmp1))[-1];
# 	    my $tmp2first = (split(/\n/, $tmp2))[0];
	    
# 	    if ($tmp1last =~ /^parent/ and $tmp1last !=~ / or / and $tmp2first =~ /^synonym/) {
# 		my @word1;
# 		if ($tmp1last =~ s/([^=]+) = ([^\(]+)\(.?$//) {
# 		    @word1 = ($1, $2);
# 		}
# 		my @word2;
# 		if ($tmp2first =~ s/^synonym :([^=]+)=([^\(]+)//) {
# 		    @word2 = ($1, $2);
# 		}
# 		if (($word1[0] eq $word2[1]) and ($word1[1] eq $word2[0])) {
# 		    $tmp1 =~ s/$tmp1last//;
# 		    $tmp2 =~ s/$tmp2first\n//;
# 		}
# 	    }
	    
# 	}
	
	# 入力の表現からDBの中の表現まで
	$loglog .= $tmp1 . $tmp2;
    }

    return if (($expression1 eq $expression_orig));

    # LOG生成
    $result = "log : $expression_orig = $expression1\n";
    if ($loglog) {
	# 入力の表現からDBの中の表現まで
	$result .= $loglog;
    }
    # DBの中の表現からSYNIDに使用されている表現まで
    $result .= "synonym : $expression2 = $expression1(\@$synid)\n" if ($expression1 ne $expression2);

    return $result;
}

sub make_relnode_log {
    my ($this, $newid, $rid, $log_reldata, $midasi, $type) = @_;
    my $log;

    my ($orig_word) = $newid->{id} =~ /s\d+:([^\/]+)/;
    my ($rel_word) = $rid =~ /s\d+:([^\/]+)/;
    if ($type eq "parent") {
	$log = "log : $newid->{midasi} = $rel_word\n";
    }
    elsif ($type eq "antonym") {
	$log = "log : $newid->{midasi} <=> $rel_word\n";
    }
    if ($newid->{log}) {
	foreach (split(/\n/, $newid->{log})){
	    next if $_ =~ /^log/;
	    $log .= "$_\n";
	}
    }
    if ($log_reldata) {
	my @rlog;
	my $key = "$newid->{id}-$rid";
	if ($this->GetValue($log_reldata->{$key})) {
	    foreach (split(/\|/, $this->GetValue($log_reldata->{$key}))) {
		my ($orig_bridge, $rel_bridge);
		if ($type eq "parent") {
		    ($orig_bridge, $rel_bridge) = split(/→/, $_);
		}
		elsif ($type eq "antonym") {
		    ($orig_bridge, $rel_bridge) = split(/-/, $_);
		}
		my $origside = (($orig_bridge eq $orig_word) ? "$orig_word" : "$orig_word = $orig_bridge")."(\@$newid->{id})";
		my $relside = (($rel_bridge eq $rel_word) ? "$rel_word" : "$rel_bridge = $rel_word")."(\@$rid)";
		if ($type eq "parent") {
		    push @rlog, "$origside => $relside";
		}
		elsif ($type eq "antonym") {
		    push @rlog, "$origside <=> $relside";
		}
	    }
	}
	my $flag;
	foreach (@rlog) {
	    unless ($flag) {
		$log .= "$type : $_";
		$flag = 1;
	    }
	    else {
		$log .= " or $_";
	    }
	}
	$log .= "\n";
    }
    
    return $log;
}

sub st_make_log {
    my ($this, $graph1, $graph2, $tmid, $match_verbose) = @_;
    my $result;
    
    # expression_orig
    my $expression_orig;
    my $expression_exam;
    my $id_orig;
    my $id_exam;
    foreach (sort {$a <=> $b} keys %{$match_verbose}) {
	my ($bp1, $num1) = split(/-/, $match_verbose->{$_}{nodedata1});
	my ($bp2, $num2) = split(/-/, $match_verbose->{$_}{nodedata2});
	
	# マッチした表現
	$expression_orig .= $graph1->[$bp1]{midasi};
	$expression_exam .= $graph2->[$bp2]{midasi};

	# マッチしたノードのID
	$id_orig .= " + " if ($id_orig);
	$id_orig .="<$graph1->[$bp1]{nodes}[$num1]{id}>";
	foreach (keys %{$penalty}) {
	    if ($graph1->[$bp1]{nodes}[$num1]{$_}) {
		if ($_ eq 'fuzoku' or $_ eq 'case') {
		    $id_orig .= "<$_:$graph1->[$bp1]{nodes}[$num1]{$_}>";
		}
		else {
		    $id_orig .= "<$_>";
		}
	    }
	}
	$id_exam .= " + " if ($id_exam);
	$id_exam .="<$graph2->[$bp2]{nodes}[$num2]{id}>";
	foreach (keys %{$penalty}) {
	    if ($graph2->[$bp2]{nodes}[$num2]{$_}) {
		if ($_ eq 'fuzoku' or $_ eq 'case') {
		    $id_exam .= "<$_:$graph2->[$bp2]{nodes}[$num2]{$_}>";
		}
		else {
		    $id_exam .= "<$_>";
		}
	    }
	}
    }

    # LOG生成
    my $id_str = ($id_orig eq $id_exam) ? $id_orig : "$id_orig = $id_exam";
    $result = "log : $tmid on [$expression_orig]\n";
    $result .= "match : $expression_orig => $id_str <= $expression_exam\n";

    return $result;
}

sub print_syngraph {
    my ($this, $syngraph) = @_;
    my $result;

    my $syn_form = $this->format_syngraph($syngraph);

    for (my $num; $num < @{$syn_form}; $num++) {
	$result .= $syn_form->[$num];
    }
    
    return $result;
}

sub format_syngraph {
    my ($this, $syngraph, $option) = @_;
    my $result;

    my $syn_bp; # 同じ基本句に対応するノードの集まり

    # !!の数
    for (my $bp_num = 0; $bp_num < @{$syngraph}; $bp_num++) { # 基本句(BP)単位
	foreach my $node (@{$syngraph->[$bp_num]{nodes}}) { # ノード単位
	    # ノードの対応する基本句番号
	    my $matchbp;
	    foreach (sort {$a <=> $b} ($node->{matchbp} ? (keys %{$node->{matchbp}}, $bp_num) : ($bp_num))) {
		$matchbp .= !defined $matchbp ? "$_" : ",$_";
	    }
	    foreach (split(/,/, $matchbp)) {
		$syn_bp->{$_}{$matchbp} = 1;
	    }
	}
    }

    # 出力生成
    for (my $bp_num = 0; $bp_num < @{$syngraph}; $bp_num++) { # 基本句(BP)単位
	my $res;
	foreach my $node (@{$syngraph->[$bp_num]{nodes}}) { # ノード単位

	    # ノードの対応する基本句番号
	    my $matchbp;
	    foreach (sort {$a <=> $b} ($node->{matchbp} ? (keys %{$node->{matchbp}}, $bp_num) : ($bp_num))) {
		$matchbp .= !defined $matchbp ? "$_" : ",$_";
	    }

	    if (!defined $res->{$matchbp}) {
		# 親
		my $parent;
		if ($syn_bp->{$syngraph->[$bp_num]{parentbp}}) {
		    foreach my $parentbp (keys %{$syn_bp->{$syngraph->[$bp_num]{parentbp}}}) {
			# 自分のノードに属する基本句のどれかが親のノードの基本句のいずれかにマッチしたら親ノードとしない
			my $flag;
			foreach my $pbp (split(/,/, $parentbp)) {
			    foreach my $mbp (split(/,/, $matchbp)) {
				if ($pbp == $mbp) {
				    $flag = 1;
				    last;
				}
			    }
			    last if ($flag);
			}
			next if ($flag);
			
			$parent .= !defined $parent ? "$parentbp" : "/$parentbp";
		    }
		}
		else { # 親が-1
		    $parent = $syngraph->[$bp_num]{parentbp};
		}

		# !!行の出力を格納
		$res->{$matchbp} = "!! $matchbp $parent$syngraph->[$bp_num]{kakari_type} <見出し:$syngraph->[$bp_num]{midasi}>";
		$res->{$matchbp} .= "<格解析結果:$node->{case}格>" if ($node->{case});
		$res->{$matchbp} .= "\n";
	    }

	    # !行の出力を格納
	    $res->{$matchbp} .= &get_nodestr($node, $matchbp, $option);
	}
	foreach my $matchbp (sort {(split(/,/, $b))[0] <=> (split(/,/, $a))[0]} (keys %{$res})) {
	    $result->[$bp_num] .= $res->{$matchbp};
	}
    }

    return $result;
}


#
# !行の生成
#
sub get_nodestr {
    my ($node, $bp, $option) = @_;
    my $string;

    # 内容語がない場合はidが空になる
    return '' unless defined $node->{id};

    # !行の出力を格納
    $string = "! $bp <SYNID:$node->{id}><スコア:$node->{score}>";
    $string .= '<反義語>' if ($node->{antonym});
    $string .= '<上位語>' if ($node->{relation});
    $string .= "<下位語数:$node->{hypo_num}>" if ($node->{hypo_num});
    $string .= '<否定>' if ($node->{negation});
    $string .= '<可能>' if ($node->{kanou});
    $string .= '<尊敬>' if ($node->{sonnkei});
    $string .= '<受身>' if ($node->{ukemi});
    $string .= '<使役>' if ($node->{shieki});

    # nodeのdetail
    if ($option->{detail}) {
	$string .= "<log:$node->{log}>" if ($node->{log});
	$string .= "<fuzoku:$node->{fuzoku}>" if ($node->{fuzoku});
	$string .= "<weight:$node->{weight}>" if ($node->{weight});
	$string .= "<wnum:$node->{wnum}>" if ($node->{wnum});
    }

    $string .= "\n";

    # nodeのlog
    if ($option->{log} or $node->{log}) {
	if ($node->{log}) {
	    my $log_flag;
	    foreach (split(/\n/, $node->{log})) {
		if ($_ =~ /^log/) {
		    $string .= "\t$_\n";
		}
		else {
		    if (!$log_flag) {
			$string .= "\t\t-----------------------------------------------------------\n";
			$log_flag = 1;
		    }
		    $string .= "\t\t$_\n";
		}
	    }
	    $string .= "\t\t-----------------------------------------------------------\n";
	}
    }

    return $string;
}

#
# SYNIDを入力、それに含まれる複数の基本句からなるSYNGRAPHを出力
#
sub expansion{
    my ($this, $synid) = @_;
    my @result;

    my %expression_cash;
    foreach my $expression (split(/\|/, $this->GetValue($this->{syndb}{$synid}))) {
	
	# ふりがな, wordid, タグ
	$expression =~ s/<定義文>|<DIC>|<Web>//g;
	$expression = (split(/\//, $expression))[0];
	
	next if $expression_cash{$expression};
	
	my $key = "$synid,$expression";

#	Dumpvalue->new->dumpValue($this->{syndata}{$key});
	push (@result, $this->{syndata}{$key});
	$expression_cash{$expression} = 1;
    }    
    
    return @result;
}


################################################################################
#                                                                              #
#                         KNP結果の読み込み 関係                               #
#                                                                              #
################################################################################

#
# KNP結果の読み込み
#
sub read_parsed_data {
    my ($this, $knp_string) = @_;
    my $knp_result;

    die unless ($this->{filehandle});

    if ($knp_string) {
        $knp_result = new KNP::Result($knp_string);
        return $knp_result;
    }
    else {
        my $fh = $this->{filehandle};
        my $knp_buf;
        my $sid;

        while (<$fh>) {
            $knp_buf .= $_;

            if (/^EOS$/) {
                $knp_result = new KNP::Result($knp_buf);
                $knp_result->set_id($sid) if ($sid);
                return $knp_result;
            }
            elsif (/\# S-ID:(.+) KNP:/) {
                $sid = $1;
                $sid =~ s/\s+/ /;
                $sid =~ s/^\s//;
                $sid =~ s/\s$//;
            }
        }

        $this->{filehandle} = undef;
        return;
    }
}


#
# KNP結果ファイルを開く
#
sub open_parsed_file {
    my ($this, $filename) = @_;
    
    my $fh = new IO::File($filename, 'r');
    if (defined $fh) {
        binmode $fh, ':encoding(euc-jp)';
        $this->{filehandle} = $fh;
        return 1;
    } else {
        return undef;
    }
}

# for index.cgi, conv_syndb.pl

sub read_synonym_pair {
    my ($syngroup_words) = @_;

    my $dicdir = $Constant::SynGraphBaseDir . '/dic/rsk_iwanami';

    my (%FREQ, %FREQ_REP);
    &SynGraph::tie_cdb($Constant::CN_DF_DB, \%FREQ);
    &SynGraph::tie_cdb($Constant::DF_REP_DB, \%FREQ_REP);

    my %allword;
    my %alldata;
    my %link;

    open S, "<:encoding(euc-jp)", "$dicdir/synonym.txt.filtered.manual" or die;
    while (<S>) {
	chomp;

	my ($target_word, @words) = split;

	if (defined $syngroup_words->{$target_word}) {
	    
	    my $freq_target_word = &get_freq($target_word, \%FREQ, \%FREQ_REP);

	    $allword{$target_word}{freq} = $freq_target_word;
	    my $comma_freq = &process_num($freq_target_word);
	    $allword{$target_word}{str} = qq("$target_word($comma_freq)");

	    for my $word (@words) {
		my $freq_word = &get_freq($word, \%FREQ, \%FREQ_REP);

		$allword{$word}{freq} = $freq_word;
		my $comma_freq = &process_num($freq_word);
		$allword{$word}{str} = qq("$word($comma_freq)");
	
		$alldata{$target_word}{$word} = 1;
		$link{$target_word}{$word} = 1;
		$link{$word}{$target_word} = 1;
	    }
	}
    }

    close S;

    open SD, "<:encoding(euc-jp)", "$dicdir/same_definition.txt" or die;
    while (<SD>) {
	chomp;

	next if /^★/;

	my @words = split;

	my $flag = 0;
	foreach my $word (@words) {
	    if (defined $syngroup_words->{$word}) {
		$flag = 1;
		last;
	    }
	}

	if ($flag) {
	    foreach my $word (@words) {
		foreach my $target_word (@words) {
		    next if $word eq $target_word;

		    next if $alldata{$target_word}{$word} eq 'samedefinition';

		    $alldata{$word}{$target_word} = 'samedefinition';
		    $link{$word}{$target_word} = 1;
		    $link{$target_word}{$word} = 1;

		    if (!defined $allword{$target_word}) {
			my $target_midasi = (split('/', $target_word))[0];
			my $freq_target_word = $FREQ{$target_midasi};
			$allword{$target_word}{freq} = $freq_target_word;

			my $comma_freq = &process_num($freq_target_word);
			$allword{$target_word}{str} = qq("$target_word($comma_freq)");
		    }

		    if (!defined $allword{$word}) {
			my $midasi = (split('/', $word))[0];
			my $freq_word = $FREQ{$midasi};
			$allword{$word}{freq} = $freq_word;

			my $comma_freq = &process_num($freq_word);
			$allword{$word}{str} = qq("$word($comma_freq)");
		    }

		}
	    }
	}
    }
    close SD;

    open D, "<:encoding(euc-jp)", "$dicdir/definition.txt.manual" or die;
    while (<D>) {
	chomp;

	my ($midasi, $definition) = split;

	if (defined $alldata{$midasi}) {
	    $alldata{$midasi}{$definition} = 1;
	    $link{$midasi}{$definition} = 1;
	    $link{$definition}{$midasi} = 1;

	    $allword{$definition}{str} = $definition;
	}
    }
    close D;

    # マージ
    my %change;
    for my $word (keys %allword) {
	# midasi -> word
	# 赤ちゃん -> 赤ちゃん:1/1:1/1
	# えんかい -> 宴会:1/1:1/1
	if ($word =~ /(.+?):(.+)/) {
	    my ($midasi, $id) = ($1, $2);

	    if (defined $allword{$midasi}) {
		$change{$midasi} = $word;
		next;
	    }

	    my ($kanji, $yomi) = split('/', $midasi);
	    if (defined $allword{$kanji}) {
		$change{$kanji} = $word;
	    }
	    elsif (defined $allword{$yomi}) {
		$change{$yomi} = $word;
	    }
	}
	# idなしで漢字/ひらがなマッチ(★)
	elsif ($word =~ /(.+?)\/(.+)/) {
	    my ($kanji, $yomi) = ($1, $2);

	    if (defined $allword{$kanji}) {
		$change{$kanji} = $word;
	    }
	    elsif (defined $allword{$yomi}) {
		$change{$yomi} = $word;
	    }
	}
    }

    for my $word1 (keys %alldata) {
	for my $word2 (keys %{$alldata{$word1}}) {
	    if (defined $change{$word2}) {
		$alldata{$word1}{$change{$word2}} = $alldata{$word1}{$word2};
		delete $alldata{$word1}{$word2};
	    }
	}
    }

    for my $word (keys %alldata) {
	if (defined $change{$word}) {
	    $alldata{$change{$word}} = $alldata{$word};
	    delete $alldata{$word};
	}
    }

    for my $word (keys %allword) {
	if (defined $change{$word}) {
	    delete $allword{$word};
	}
    }

    my %WORD2FREQ;
    &tie_cdb($Constant::SYNONYM_WORD2FREQ_DB, \%WORD2FREQ);

    # rankをひく
    for my $word (keys %allword) {
	my $midasi = (split(':', $word))[0];

	$allword{$word}{rank} = (split(':', $WORD2FREQ{$midasi}))[0];
    }
    return (\%allword, \%alldata, \%link);
}

sub get_freq {
    my ($word, $FREQ, $FREQ_REP) = @_;

    my $rep = (split(':', $word))[0];
    my $midasi = (split('/', $word))[0];

    return defined $FREQ->{"$midasi"} ? $FREQ->{"$midasi"} : defined $FREQ_REP->{$rep} ? (split(':', $FREQ_REP->{$rep}))[1] * 3 : undef;
#    return $FREQ->{$midasi};
}

################################################################################
#                                                                              #
#                              データベース 関係                               #
#                                                                              #
################################################################################

#
# DB情報をセット
#
sub db_set {
    my ($this, $db_hash) = @_;

    $this->{db_type} = $db_hash->{type};
    $this->{db_name} = $db_hash->{name};
    $this->{db_table} = $db_hash->{table};
}


#
# DBに接続
#
sub db_connect {
    my ($this, $create) = @_;

    if ($this->{db_type} eq 'mysql') {
        $this->_mysql_connect;
    }
    elsif ($this->{db_type} eq 'mldbm') {
        # 書き込みモード
        if ($create) {
            $this->_mldbm_create;
        }
        # 読み込みモード
        else {
            $this->_mldbm_tie;
        }
    }
}


#
# SYNGRAPHをDBに登録
#
sub db_register {
    my ($this, $ref, $sid) = @_;

    if ($this->{db_type} eq 'mysql') {
        $this->_mysql_register($ref, $sid);
    }
    elsif ($this->{db_type} eq 'mldbm') {
        $this->_mldbm_register($ref, $sid);
    }
}


#
# DBに登録された文IDのリストを取得
#
sub db_sidlist {
    my ($this) = @_;

    if ($this->{db_type} eq 'mysql') {
        return $this->_mysql_sidlist;
    }
    elsif ($this->{db_type} eq 'mldbm') {
        return $this->_mldbm_sidlist;
    }
}


#
# SYNGRAPHをDBから取得
#
sub db_retrieve {
    my ($this, $ref, $list_ref) = @_;

    if ($this->{db_type} eq 'mysql') {
        $this->_mysql_retrieve($ref, $list_ref);
    }
    elsif ($this->{db_type} eq 'mldbm') {
        $this->_mldbm_retrieve($ref, $list_ref);
    }
}


#
# DBを切断
#
sub db_disconnect {
    my ($this) = @_;

    if ($this->{db_type} eq 'mysql') {
        $this->_mysql_disconnect;
    }
    elsif ($this->{db_type} eq 'mldbm') {
        $this->_mldbm_disconnect;
    }
}



################################################################################
#                                                                              #
#                                  mysql 関係                                  #
#                                                                              #
################################################################################

#
# mysqlに接続
#
sub _mysql_connect {
    my ($this) = @_;

    require DBI;

    my $hostname = "localhost";
    my $dsn = "DBI:mysql:database=$this->{db_name}:host=$hostname";
    my $user = "root";
    my $password = "";
    $this->{dbh} = DBI->connect($dsn, $user, $password) or die $DBI::errstr;
}


#
# SYNGRAPHをmysqlに登録
#
sub _mysql_register {
    my ($this, $ref, $sid) = @_;

    unless ($this->{sth}) {
        # プレースホルダを利用したSQL文の用意
        $this->{sth} = $this->{dbh}->prepare("INSERT INTO $this->{db_table} VALUES (?, ?)") or die $this->{dbh}->errstr;
    }

    # SYNGRAPHをシリアライズ
    my $serialized = freeze($ref->{$sid});

    # 値を挿入
    $this->{sth}->execute($sid, $serialized) or die $this->{sth}->errstr;
}


#
# mysqlに登録された文IDのリストを取得
#
sub _mysql_sidlist {
    my ($this) = @_;
    my $sid;
    my @sidlist;

    # 準備
    $this->{sth} = $this->{dbh}->prepare("SELECT sid FROM $this->{db_table}") or die $this->{dbh}->errstr;
    # 実行
    $this->{sth}->execute or die $this->{sth}->errstr;

    # それぞれの変数をカラムとバインド
    $this->{sth}->bind_col(1,\$sid);

    # 結果を読み取る
    while ($this->{sth}->fetch) {
        push(@sidlist, $sid);
    }

    return @sidlist;
}


#
# SYNGRAPHをmysqlから取得
#
sub _mysql_retrieve {
    my ($this, $ref, $list_ref) = @_;

    return unless (@$list_ref);

    # 準備
    my $sql_query = "SELECT sid, serialized FROM $this->{db_table} WHERE " . join(" or ", map("sid like '$_%'", @$list_ref));
    $this->{sth} = $this->{dbh}->prepare($sql_query) or die $this->{dbh}->errstr;
    # 実行
    $this->{sth}->execute or die $this->{sth}->errstr;

    # 結果を受け取る変数
    my ($sid, $serialized);
    # それぞれの変数をカラムとバインドe
    $this->{sth}->bind_col(1,\$sid);
    $this->{sth}->bind_col(2,\$serialized);
    # 結果を読み取る
    while ($this->{sth}->fetch) {
        # 解凍
        $ref->{$sid} = thaw($serialized);
    }
}


#
# mysqlを切断 
#
sub _mysql_disconnect {
    my ($this) = @_;

    $this->{dbh}->disconnect;
}



################################################################################
#                                                                              #
#                                  MLDBM 関係                                  #
#                                                                              #
################################################################################

#
# MLDBMをtie
#
sub _mldbm_create {
    my ($this) = @_;

    $this->{dbh} = {};
    &create_mldbm($this->{db_name}, $this->{dbh});
}


#
# MLDBMをtie
#
sub _mldbm_tie {
    my ($this) = @_;

    $this->{dbh} = {};
    &tie_mldbm($this->{db_name}, $this->{dbh});
}


#
# SYNGRAPHをMLDBMに登録
#
sub _mldbm_register {
    my ($this, $ref, $sid) = @_;

    $this->{dbh}->{$sid} = $ref->{$sid};
}


#
# MLDBMに登録された文IDのリストを取得
#
sub _mldbm_sidlist {
    my ($this) = @_;

    return sort keys %{$this->{dbh}};
}


#
# SYNGRAPHをMLDBMから取得
#
sub _mldbm_retrieve {
    my ($this, $ref, $list_ref) = @_;

    foreach my $sid (@$list_ref) {
        $ref->{$sid} = $this->{dbh}->{$sid};
    }
}


#
# st_data*.mldbmからkeyのvalueを取得して返す
#
sub get_st_data_value {
    my ($this, $ref, $key) = @_;

    if (ref $ref eq 'ARRAY') {
	foreach my $st_data (@{$ref}) {
	    return $st_data->{$key} if (defined $st_data->{$key});
	}
    }
    else {
	return $this->{st_data}->{$key};
    }
}


#
# MLDBMをuntie
#
sub _mldbm_disconnect {
    my ($this) = @_;

    untie %{$this->{dbh}};
}



################################################################################
#                                                                              #
#                               類義表現DB 関係                                #
#                                                                              #
################################################################################

#
# 類義表現DBの読み込み
#
sub retrieve_syndb {
    my ($this, $syndata, $synhead, $synparent, $synantonym) = @_;
    $syndata = '../syndb/i686/syndata.mldbm' unless ($syndata);
    $synhead = '../syndb/i686/synhead.cdb' unless ($synhead);
    $synparent = '../syndb/i686/synparent.cdb' unless ($synparent);
    $synantonym = '../syndb/i686/synantonym.cdb' unless ($synantonym);

    &retrieve_mldbm($syndata, $this->{syndata});
    &retrieve_cdb($synhead, $this->{synhead});
    &retrieve_cdb($synparent, $this->{synparent});
    &retrieve_cdb($synantonym, $this->{synantonym});
}


#
# 類義表現DBをtie
#
sub tie_syndb {
    my ($this, $syndata, $synhead, $synparent, $synantonym) = @_;
    $syndata = '../syndb/i686/syndata.mldbm' unless ($syndata);
    $synhead = '../syndb/i686/synhead.cdb' . $this->{dbext} unless ($synhead);
    $synparent = '../syndb/i686/synparent.cdb' . $this->{dbext} unless ($synparent);
    $synantonym = '../syndb/i686/synantonym.cdb' . $this->{dbext}  unless ($synantonym);

    &tie_mldbm($syndata, $this->{syndata});
    &tie_cdb($synhead, $this->{synhead});
    &tie_cdb($synparent, $this->{synparent});
    &tie_cdb($synantonym, $this->{synantonym});
}

#
# syndbチェック用のDBをtie
#
sub tie_forsyndbcheck {
    my ($this, $syndb, $synnumber, $synchild, $log_isa, $log_antonym) = @_;

    $syndb = '../cgi/syndb.cdb' unless ($syndb);
    $synnumber = '../cgi/synnumber.cdb' unless ($synnumber);
    $synchild = '../cgi/synchild.cdb' unless ($synchild);
    $log_isa = '../cgi/log_isa.cdb' unless ($log_isa);
    $log_antonym = '../cgi/log_antonym.cdb' unless ($log_antonym);

    &tie_cdb($syndb, $this->{syndb});
    &tie_cdb($synnumber, $this->{synnumber});
    &tie_cdb($synchild, $this->{synchild});
    &tie_cdb($log_isa, $this->{log_isa});
    &tie_cdb($log_antonym, $this->{log_antonym});
}



#
# 類義表現DBをuntie
#
sub untie_syndb {
    my ($this) = @_;

    untie %{$this->{synhead}};
    untie %{$this->{syndata}};
    untie %{$this->{synparent}};
    untie %{$this->{synantonym}};
}



################################################################################
#                                                                              #
#                               BerkeleyDB関係                                 #
#                                                                              #
################################################################################

#
# BerkeleyDBに保存
#
sub store_db {
    my ($filename, $hash_ref) = @_;
    my %hash;

    # ファイルを消して作りなおす
    my $db = tie %hash, 'BerkeleyDB::Hash', -Filename => $filename, -Flags => DB_CREATE, -Cachesize => 100000000 or die "Cannot tie '$filename'";

    # filter setting
    $db->filter_fetch_key(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_key(sub{$_ = &encode('euc-jp', $_)});
    $db->filter_fetch_value(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_value(sub{$_ = &encode('euc-jp', $_)});
    
    while (my ($key, $value) = each %$hash_ref) {
	$hash{$key} = $value;
    }
    untie %hash;
}

#
# DBの読み込み (前もって全部読み込んでおく)
#
sub retrieve_db {
    my ($filename, $hash_ref) = @_;
    my %hash;

    &tie_db($filename, \%hash);
    while (my ($key, $value) = each %hash) {
        $hash_ref->{$key} = $value;
    }
    untie %hash;
}


#
# BerkeleyDBをtie
#
sub tie_db {
    my ($filename, $hash_ref) = @_;

    my $db = tie %$hash_ref, 'BerkeleyDB::Hash', -Filename => $filename, -Flags => DB_RDONLY, -Cachesize => 100000000 or die "Cannot tie '$filename'";

    # filter setting
    $db->filter_fetch_key(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_key(sub{$_ = &encode('euc-jp', $_)});
    $db->filter_fetch_value(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_value(sub{$_ = &encode('euc-jp', $_)});
}


################################################################################
#                                                                              #
#                                CDB 関係                                      #
#                                                                              #
################################################################################

#
# CDBに保存
#
sub store_cdb {
    my ($filename, $hash_ref) = @_;
    my %hash;
    
    my $db =  new CDB_File($filename, "$filename.$$") or die $!;
    while (my ($key, $value) = each %$hash_ref) {
	$db->insert($key, $value);
    }
    $db->finish;
}

#
# CDBの読み込み (前もって全部読み込んでおく)
#
sub retrieve_cdb {
    my ($filename, $hash_ref) = @_;
    my %hash;

    &tie_cdb($filename, \%hash);
    while (my ($key, $value) = each %hash) {
	$key = &decode('utf8', $key);
	$value = &decode('utf8', $value);
        $hash_ref->{$key} = $value;
    }
    untie %hash;
}


#
# CDBをtie
#
sub tie_cdb {
    my ($filename, $hash_ref) = @_;

    my $db = tie %$hash_ref, 'CDB_File', $filename or die "Cannot tie '$filename'";

}


# データベースの値を得る
# cdbの場合はdecodeする
sub GetValue {
    my ($this, $value) = @_;

    return $this->{db_on_memory} ? $value : &decode('utf8', $value);
}


################################################################################
#                                                                              #
#                                  MLDBM 関係                                  #
#                                                                              #
################################################################################

#
# MLDBMに保存 (全部一括して保存)
#
sub store_mldbm {
    my ($filename, $hash_ref) = @_;
    my %hash;

    &create_mldbm($filename, \%hash);
    while (my ($key, $value) = each %$hash_ref) {
        $hash{$key} = $value;
    }
    untie %hash;
}


#
# MLDBMの読み込み (前もって全部読み込んでおく)
#
sub retrieve_mldbm {
    my ($filename, $hash_ref) = @_;
    my %hash;

    &tie_mldbm($filename, \%hash);
    while (my ($key, $value) = each %hash) {
        $hash_ref->{$key} = $value;
    }
    untie %hash;
}


#
# MLDBMを保存用にtie
#
sub create_mldbm {
    my ($filename, $hash_ref) = @_;

    my $db = tie %$hash_ref, 'MLDBM', -Filename => $filename, -Flags => DB_CREATE or die "Cannot tie '$filename'";

    # filter setting
    $db->filter_fetch_key(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_key(sub{$_ = &encode('euc-jp', $_)});
    $db->filter_fetch_value(sub{});
    $db->filter_store_value(sub{});
}


#
# MLDBMを読み込み専用でtie
#
sub tie_mldbm {
    my ($filename, $hash_ref) = @_;

    my $db = tie %$hash_ref, 'MLDBM', -Filename => $filename, -Flags => DB_RDONLY or die "Cannot tie '$filename'";

    # filter setting
    $db->filter_fetch_key(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_key(sub{$_ = &encode('euc-jp', $_)});
    $db->filter_fetch_value(sub{});
    $db->filter_store_value(sub{});
}


################################################################################
#                                                                              #
#                               半角を全角に変換                               #
#                                                                              #
################################################################################

sub h2z {
    my ($string) = @_;
    
    # 全角に変換
    $string =~ tr/0-9A-Za-z !\"\#$%&\'()*+,-.\/:;<=>?@[\\]^_\`{|}~/０-９Ａ-Ｚａ-ｚ　！”＃＄％＆’（）＊＋，−．／：；＜＝＞？＠［￥］＾＿‘｛｜｝〜/;

    return $string;
}


#
# XMLからキーワードを取り出す
#
sub _read_xml {
    my ($this, $xml_buf, $tree_ref, $tmid) = @_;
    my $sen;

    # リファレンスで渡された場合
    if (ref $xml_buf) {
        $sen = $xml_buf;
    }
    # XMLテキストの場合
    else {
        require XML::Simple;
        my $xml = new XML::Simple;
        $sen = $xml->XMLin($xml_buf, ForceArray => 1, keyattr => []);
    }

    # 木を作る
    # by NICT
    ### MODIFIED NICT200707
    ###   2パスに変更する。1回目：$child,$bp_tableテーブル設定  2回目：結果登録
    my $child = {};
    my $bp_table = {};
    foreach my $step ('prep','do') {
	my $org_num = -1;
	my $key_num = 0;
	# my $child = {};
	# my $bp_table = {};
	foreach my $phrase (@{$sen->{phrase}}) {
	    my $nodename = [];
	    my $numid;
	    my $fuzoku;
	    my $negation;
	    $org_num++;

	    # 元の文のフレーズ番号
	    my $org_pnum = $phrase->{org_pnum} ? $phrase->{org_pnum} : $org_num;

	    # bondは無視
	    next if ($phrase->{bond} == 1);

	    if( $step eq 'prep' ) {
		# BP番号のテーブル
		$bp_table->{$org_num} = $key_num;

		# 子供
		$child->{$phrase->{dpnd}}->{$org_num} = 1 if ($phrase->{dpnd} != -1);
	    }

	    foreach my $word (@{$phrase->{word}}) {
		# 句点、読点は無視
		if ($word->{pos} =~ /:(句点|読点)/) {
		    next;
		}

		# 「お」は無視
		elsif ($word->{content_p} == -1 and $word->{lem} =~ /^(お|ご|御)$/) {
		    next;
		}

		# 否定表現
		elsif ($word->{content_p} == -1 and $word->{lem} =~ /^(非|不)$/) {
		    $negation = 1;
		}

		# 自立語
		elsif ($word->{content_p} != 0 or
		       $word->{pos} eq '名詞:形式名詞') {
		    # 活用させずにそのまま
		    if (defined $word->{kanou_norm}) {
			push (@{$nodename}, [$word->{kanou_norm}]);
		    }
		    elsif (defined $word->{sonkei_norm}) {
			push (@{$nodename}, [split(/:/, $word->{sonkei_norm})]);
		    } else {
			push (@{$nodename}, [$word->{lem}]);
		    }
		    $numid .= $word->{lem} if ($numid);
		    # 数字の汎化
		    if ($word->{pos} eq '名詞:数詞' and
			$word->{lem} ne '何' and
			$word->{lem} ne '幾') {
			$numid .= '<num>';
		    }
		}
		# その他、付属語
		else {
		    # キーワード扱い
		    if ($word->{pos} =~ /^接尾辞:名詞性(名詞|特殊)/ or
			($word->{pos} eq '接尾辞:名詞性述語接尾辞' and $word->{read} eq 'かた')) {
			if (defined $word->{kanou_norm}) {
			    push (@{$nodename}, [$word->{kanou_norm}]);
			}
			elsif (defined $word->{sonkei_norm}) {
			    push (@{$nodename}, [split(/:/, $word->{sonkei_norm})]);
			} else {
			    push (@{$nodename}, [$word->{lem}]);
			}
			$numid .= $word->{lem} if ($numid);
		    }
		    # 否定表現
		    elsif (($word->{pos} =~ /^接尾辞/ and $word->{lem} eq 'ない') or
			   ($word->{pos} eq '助動詞' and $word->{lem} eq 'ぬ')) {
			$negation = 1;
		    }
		    else {
			# 一番最後は付属語なし
			$fuzoku .= $word->{lem} if ($phrase->{dpnd} != -1);
		    }
		}
	    }

	    # next if ($#{$nodename} < 0);

#         # チェック用
#         unless ($nodename) {
#             return;
#             use Dumpvalue;
#             Dumpvalue->new->dumpValue($sen);
#             print "--------\n";
#         }

	    if( $step eq 'do' ) {
		# 子供BPの変換
		my $childbp = {};
		foreach my $org_child (keys %{$child->{$org_num}}) {
		    if (exists $bp_table->{$org_child}) {
			$childbp->{$bp_table->{$org_child}} = 1;
		    }
		}

		my @nodename_list;
		push (@nodename_list, "");
		for (my $i = 0; $i < @{$nodename}; $i++) {
		    my @tmp;
		    for (my $j = 0; $j < @{$nodename->[$i]}; $j++) {
			foreach my $str (@nodename_list) {
			    push (@tmp, "$str$nodename->[$i][$j]");
			}
		    }
		    @nodename_list = @tmp;
		}

		# ID登録
		foreach my $str (@nodename_list) {
		    #regnode_optionが入力に必要かも(odani)
		    $this->_regnode({ref      => $tree_ref,
				     sid      => $tmid,
				     bp       => $key_num,
				     id       => $str,
				     fuzoku   => $fuzoku,
				     negation => $negation,
				     childbp  => $childbp,
				     origbp   => $org_pnum,
				     negation => 0,
				     score    => 1,
				     weight   => 1,
				     wnum     => $phrase->{word}[0]{wnum}});
		}

		#regnode_optionが入力に必要かも(odani)
		$this->_regnode({ref      => $tree_ref,
				 sid      => $tmid,
				 bp       => $key_num,
				 id       => $numid,
				 fuzoku   => $fuzoku,
				 negation => $negation,   ### 要修正
				 childbp  => $childbp,
				 origbp   => $org_pnum,
				 negation => 0,           ### 要修正
				 score    => 1,
				 weight   => 1,
				 wnum     => $phrase->{word}[0]{wnum}}) if ($numid);
	    }

	    $key_num++;
	}
    }
}

sub process_num {
    my ($num) = @_;

    while($num =~ s/(.*\d)(\d\d\d)/$1,$2/){} ;

    return $num;
}

1;
