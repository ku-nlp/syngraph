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

#
# 定数
#

# 同義語のペナルティ
my $synonym_penalty = 0.99;
# 上位・下位のペナルティ
my $relation_penalty = 0.7;
# 反義語のペナルティ
my $antonym_penalty = 0.8;

# 要素の違いによるペナルティ
our $penalty = {fuzoku => 1.0,     # 付属語
		case => 0.3,       # 格
		kanou => 0.8,      # 可能表現
		sonnkei => 1,      # 尊敬表現
		ukemi => 0.3,      # 受身表現
		shieki => 0.3,     # 使役表現
		negation => 0.3};  # 否定

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
        st_data    => {},
        tm_sg      => {},
	knp        => new KNP(%knp_pm_args),
	# by NICT
	fast       => $option->{fast},
    };
    
    bless $this;

    if (defined $syndbdir and $syndbdir ne "") { # by NICT
	# 類義表現DBをtie
	$this->tie_syndb("$syndbdir/syndata.mldbm", "$syndbdir/synhead.cdb", "$syndbdir/synparent.cdb", "$syndbdir/synantonym.cdb");
	
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
	    }
	    
	    # SYNGRAPHに登録
            $this->_regnode({ref         => $tree_ref,
                             sid         => $sid,
                             bp          => $bp_num,
                             id          => $node->{name},
			     log         => $log,
                             fuzoku      => $node->{fuzoku},
			     midasi      => $node->{midasi},
                             childbp     => $node->{child},
			     parentbp    => $node->{parent},
			     kakari_type => $node->{kakari_type},
			     case        => $node->{case},
                             kanou       => $node->{kanou},
			     sonnkei     => $node->{sonnkei},
                             ukemi       => $node->{ukemi},
			     shieki      => $node->{shieki},
			     negation    => $node->{negation},
			     level       => $node->{level},
                             score       => 1,
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
    foreach my $node (@{$ref->{$sid}[$bp]}) {
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

 		# マッチ調べる
		$this->{matching} = 'matching';
		my $result = $this->syngraph_matching($ref->{$sid}, $bp, $this->{syndatacache}{$mid}, $headbp);
		next if $this->{matching} eq 'unmatch';

		# 新たなSYNノードとして貼り付けてよいかどうかをチェック
		# SYNノードとしての要素を獲得
		my $nodefac = $this->get_nodefac('syn', $ref->{$sid}, $bp, $this->{syndatacache}{$mid}, $headbp, $result);
		next if ($this->{matching} eq 'unmatch');

		# NODEのLOG
		my $log;
		if ($option->{log}) {
		    $log = $this->make_log($ref->{$sid}, $this->{syndatacache}{$mid}, $mid, $result);
		}

		$this->_regnode({ref            => $ref,
				 sid            => $sid,
				 bp             => $bp,
				 id             => $synid2,
				 log            => $log,
				 fuzoku         => $nodefac->{fuzoku},
				 midasi         => $nodefac->{midasi},
				 matchbp        => $nodefac->{matchbp},
				 childbp        => $nodefac->{childbp},
				 parentbp       => $nodefac->{parentbp},
				 kakari_type    => $nodefac->{kakari_type},
				 case           => $nodefac->{case},
				 kanou          => $nodefac->{kanou},
				 sonnkei        => $nodefac->{sonnkei},
				 ukemi          => $nodefac->{ukemi},
				 shieki         => $nodefac->{shieki},
				 negation       => $nodefac->{negation},
				 level          => $nodefac->{level}, 
				 score          => $nodefac->{score} * $synonym_penalty,
				 weight         => $nodefac->{weight},
				 relation       => $nodefac->{relation},
				 antonym        => $nodefac->{antonym},
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

    foreach my $node (@{$ref->{$sid}[$bp]}) {
        next if ($node->{weight} == 0);

	my %count_pattern;
	my %stid_tmp;
        if ($node->{id} and $this->{st_head}{$node->{id}}) {
            foreach my $stid (@{$this->{st_head}{$node->{id}}}) {
                my $headbp = $this->{st_data}{$stid}{head};
                my $tmid = $this->{st_data}{$stid}{tmid};
                my %body;
                map {$body{$_} = 1} split(" ", $this->{st_data}{$stid}{body});

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
		    foreach my $estr (@{$this->{st_data}{$stid}{mvalue}}) {
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
                
		# マッチ調べる
		$this->{matching} = 'matching';
		my $result = $this->syngraph_matching($ref->{$sid}, $bp, $this->{tm_sg}{$tmid}, $headbp,
							  \%body, $matching_option);
		if ($this->{matching} eq 'unmatch') {
		    delete $this->{tm_sg}{$tmid};
		    next;
		}

		# ノードとしての要素を獲得
		my $nodefac = $this->get_nodefac('MT', $ref->{$sid}, $bp, $this->{tm_sg}{$tmid}, $headbp, $result, $option);
		if ($this->{matching} eq 'unmatch') {
		    delete $this->{tm_sg}{$tmid};
		    next;
		}

		# 入力の文節番号集合
		my @s_body;
		foreach my $i (@{$nodefac->{match}}) {
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
		    $log = $this->st_make_log($ref->{$sid}, $this->{tm_sg}{$tmid}, $tmid, $result);		    
		}

		delete $this->{tm_sg}{$tmid} if ($option->{clear_cache});

		my $newid =
		    # シソーラス、反義語データベースは使用しない
		    $this->_regnode({ref            => $ref,
				     sid            => $sid,
				     bp             => $bp,
				     id             => $stid,
				     log            => $log,
				     fuzoku         => $nodefac->{fuzoku},
				     midasi         => $nodefac->{midasi},
				     matchbp        => $nodefac->{matchbp},
				     childbp        => $nodefac->{childbp},
				     parentbp       => $nodefac->{parentbp},
				     kakari_type    => $nodefac->{kakari_type},
				     case           => $nodefac->{case},
				     kanou          => $nodefac->{kanou},
				     sonnkei        => $nodefac->{sonnkei},
				     ukemi          => $nodefac->{ukemi},
				     shieki         => $nodefac->{shieki},
				     negation       => $nodefac->{negation},
				     level          => $nodefac->{level}, 
				     score          => $nodefac->{score} * $synonym_penalty,
				     weight         => $nodefac->{weight}
				 });

		$newid->{matchid}   = $nodefac->{matchid} if ($newid);
		$newid->{match}     = $nodefac->{match} if ($newid);
		$newid->{matchpair} = $nodefac->{matchpair} if ($newid);
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
	    foreach my $node_case (split(/;/, $4)){
		# 要修正
		push (my @node_case_feature, split(/\//, $node_case));
		$case->{$node_case_feature[3]}{$tag->{id}} = $node_case_feature[0] unless ($node_case_feature[3] =~ /-/);
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

        foreach my $mrph ($tag->mrph) {
            next if ($mrph->{hinsi} eq '特殊' and $mrph->{bunrui} ne '記号');

            # 意味有
            if ($mrph->{fstring} =~ /<意味有>/ ||
		# -copulaのとき、判定詞には<意味有>がないので、特別処理
		($mrph->{fstring} =~ /<後処理\-基本句始>/ && $mrph->hinsi eq "判定詞")) {

		my $nodename_str;
		# 可能動詞であれば戻す
		if ($mrph->{fstring} =~ /<可能動詞:([^\s\">]+)/) {
		    $nodename_str = $1;
		}
		# 尊敬動詞であれば戻す
		elsif ($mrph->{fstring} =~ /<尊敬動詞:([^\s\">]+)/) {
		    $nodename_str = $1;
		}
                # 代表表記
                elsif ($mrph->{fstring} =~ /<代表表記:([^\s\">]+)/) {
		    $nodename_str = $1;
                }
                # 擬似代表表記
                elsif ($mrph->{fstring} =~ /<疑似代表表記:([^\s\">]+)/) {
		    $nodename_str = $1;
                }
                else {
		    $nodename_str = $mrph->{genkei};
                }

		# 数詞の汎化
		if ($mrph->{hinsi} eq "名詞" && $mrph->{bunrui} eq "数詞" &&
		    $mrph->{genkei} !~ /^(何|幾|数|なん|いく|すう)$/) {
		    $nodename .= !$nodename ? "$nodename_str" : "+$nodename_str";
		    $nodename_num .= !$nodename_num ? "<num>" : "+<num>";
		} else {
		    $nodename .= !$nodename ? "$nodename_str" : "+$nodename_str";
		    $nodename_num .= !$nodename_num ? "$nodename_str" : "+$nodename_str";
		}

                # ALT<ALT-あえる-あえる-あえる-2-0-1-2-"ドメイン:料理・食事 代表表記:和える/あえる">
                if (my @tmp = ($mrph->{fstring} =~ /(<ALT.+?>)/g)) {
		    foreach (@tmp){
			# 可能動詞であれば戻す
			if ($_ =~ /可能動詞:([^\s\">]+)/) {
			    push(@alt,$1);
			}
			# 尊敬動詞であれば戻す
			elsif ($_ =~ /尊敬動詞:([^\s\">]+)/) {
			    push(@alt,$1);
			}
			# 代表表記
			elsif ($_ =~ /代表表記:([^\s\">]+)/){
			    push(@alt,$1);
			}
		    }
                }
#                 # コンパイル時はALTは使わない場合
#                 if ($this->{mode} eq 'compile' and @alt > 0) {
#                     undef @alt;
#                 }

                # 品詞変更<品詞変更:動き-うごき-動く-2-0-2-8-"代表表記:動く/うごく">
		# 「歩き方」＝「歩く方法」
		# ただし利用は文末以外
		if ($tag->{parent}) {
		    while ($mrph->{fstring} =~ /(<品詞変更.+?>)/g) {
			# 代表表記
			if ($1 =~ /代表表記:([^\s\">]+)/){
			    push(@alt,$1);		
			}
		    }
		}

                # 同義<同義:方法/ほうほう>
                while ($mrph->{fstring} =~ /(<同義.+?>)/g) {
		    # 代表表記
		    if ($1 =~ /同義:([^\s\">]+)/){
			push(@alt,$1);		
		    }
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

#         # チェック用
#         unless ($nodename) {
#           return;
#             print $knp_result->all;
#             use Dumpvalue;
#             Dumpvalue->new->dumpValue(\@keywords);
#             print "--------\n";
#         }
	
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
	push(@{$keywords[$tag->{id}]}, \%tmp);
	
	# ALTの処理(意味有が1形態素と仮定)
	foreach my $alt_key (@alt) {
	    # 表記が同じものは無視
	    next if (grep($alt_key eq $_->{name}, @{$keywords[$tag->{id}]}));
	    # 登録
	    my %tmp2 = %tmp;
	    $tmp2{name} = $alt_key;
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
    my $parentbp              = $args_hash->{parentbp};
    my $kakari_type           = $args_hash->{kakari_type};
    my $case                  = $args_hash->{case};
    my $kanou                 = $args_hash->{kanou};
    my $sonnkei               = $args_hash->{sonnkei};
    my $ukemi                 = $args_hash->{ukemi};
    my $shieki                = $args_hash->{shieki};
    my $negation              = $args_hash->{negation};
    my $level                 = $args_hash->{level};
    my $score                 = $args_hash->{score};
    my $weight                = $args_hash->{weight};
    my $relation              = $args_hash->{relation};
    my $hypo_num              = $args_hash->{hypo_num};
    my $antonym               = $args_hash->{antonym};
    my $wnum                  = $args_hash->{wnum};
    my $regnode_option        = $args_hash->{regnode_option};

    # コンパイルでは完全に一致する部分にはIDを付与しない
    return if ($this->{mode} eq 'repeat' and $bp == @{$ref->{$sid}} - 1 and !$childbp);

    # スコアが小さいIDは登録しない
    if ($score >= $regnode_threshold or ($this->{mode} =~ /irex/ and $weight == 0)) {
        # 既にそのIDが登録されていないかチェック
        if ($ref->{$sid}[$bp]) {
            foreach my $i (@{$ref->{$sid}[$bp]}) {
                if ($i->{id}        eq $id and
                    $i->{kanou}     == $kanou and
                    $i->{sonnkei}   == $sonnkei and
		    $i->{ukemi}     == $ukemi and
		    $i->{shieki}    == $shieki and
                    $i->{negation}  == $negation and
                    $i->{level}     == $level and
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
	$newid->{midasi} = $midasi if ($midasi);
        if ($childbp) {
	    foreach my $c (keys %{$childbp}) {
		$newid->{childbp}{$c} = 1;
	    }
	}
	$newid->{parentbp} = $parentbp if ($parentbp);
	$newid->{kakari_type} = $kakari_type if ($kakari_type);
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
        $newid->{level}    = $level if ($level);
        $newid->{score}    = $score;
        $newid->{weight}   = $weight;
        $newid->{relation} = $relation if ($relation);
        $newid->{hypo_num} = $hypo_num if ($hypo_num);
        $newid->{wnum}     = $wnum if($wnum);
        $newid->{antonym}  = $antonym if ($antonym);
        push(@{$ref->{$sid}[$bp]}, $newid);

	# 上位IDがあれば登録(ただし上位語の上位語や、反義語の上位語は登録しない)
	if ($regnode_option->{relation} and $relation != 1 and $antonym != 1){

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
			my ($parentword) = $pid =~ /s\d+:([^\/]+)/;
			my ($childword) = $newid->{id} =~ /s\d+:([^\/]+)/;
			$log = "log : $newid->{midasi} = $parentword\n";
			if ($newid->{log}) {
			    foreach (split(/\n/, $newid->{log})){
				next if $_ =~ /^log/;
				$log .= "$_\n";
			    }
			}
			my @plog;
			if ($this->{log_isa}) {
			    foreach (split(/\|/, $this->GetValue($this->{log_isa}{"$newid->{id}-$pid"}))) {
				my ($child_bridge, $parent_bridge) = split(/→/, $_);
				my $childside = (($child_bridge eq $childword) ? "$childword" : "$childword = $child_bridge")."(\@$newid->{id})";
				my $parentside = (($parent_bridge eq $parentword) ? "$parentword" : "$parent_bridge = $parentword")."(\@$pid)";
				push @plog, "$childside => $parentside";
			    }
			    my $flag;
			    foreach (@plog) {
				unless ($flag) {
				    $log .= "parent : $_";
				    $flag = 1;
				}
				else {
				    $log .= " or $_";
				}
			    }
			    $log .= "\n";
			}
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
				     parentbp       => $parentbp,
				     kakari_type    => $kakari_type,
				     case           => $case,
				     kanou          => $kanou,
				     sonnkei        => $sonnkei,
				     ukemi          => $ukemi,
				     shieki         => $shieki,
				     negation       => $negation,
				     level          => $level,
				     score          => $score * $relation_penalty,
				     weight         => $weight,
				     regnode_option => $regnode_option,
				     relation       => 1,
				     hypo_num       => $number
				 });
		}
	    }
	}

	if ($regnode_option->{antonym}){
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
			my ($word1) = $newid->{id} =~ /s\d+:([^\/]+)/;
			my ($word2) = $aid =~ /s\d+:([^\/]+)/;
			$log = "log : $newid->{midasi} <=> $word2\n";
			if ($newid->{log}) {
			    foreach (split(/\n/, $newid->{log})){
				next if $_ =~ /^log/;
				$log .= "$_\n";
			    }
			}
			if ($this->{log_antonym}) {
			    my @alog;
			    if ($this->{log_antonym}{"$newid->{id}-$aid"}) {
				foreach (split(/\|/, $this->GetValue($this->{log_antonym}{"$newid->{id}-$aid"}))) {
				    my ($word1_bridge, $word2_bridge) = split(/-/, $_);
				    my $word1_side = (($word1_bridge eq $word1) ? "$word1" : "$word1 = $word1_bridge")."(\@$newid->{id})";
				    my $word2_side = (($word2_bridge eq $word2) ? "$word2" : "$word2_bridge = $word2")."(\@$aid)";
				    push @alog, "$word1_side <=> $word2_side";
				}
			    }
			    if ($this->{log_antonym}{"$aid-$newid->{id}"}) {
				foreach (split(/\|/, $this->GetValue($this->{log_antonym}{"$aid-$newid->{id}"}))) {
				    my ($word2_bridge, $word1_bridge) = split(/-/, $_);
				    my $word1_side = (($word1_bridge eq $word1) ? "$word1" : "$word1 = $word1_bridge")."(\@$newid->{id})";
				    my $word2_side = (($word2_bridge eq $word2) ? "$word2" : "$word2_bridge = $word2")."(\@$aid)";
				    push @alog, "$word1_side <=> $word2_side" if (!grep("$word1_side <=> $word2_side" eq $_, @alog));
				}
			    }
			    my $alog_str;
			    foreach (@alog) {
				if ($alog_str) {
				    $alog_str .= " or $_";
				}
				else {
				    $alog_str .= "antonym : $_";
				}
			    }
			    $log .= "$alog_str\n";
			}
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
				     parentbp       => $parentbp,
				     kakari_type    => $kakari_type,
				     case           => $case,
				     kanou          => $kanou,
				     sonnkei        => $sonnkei,
				     ukemi          => $ukemi,
				     shieki         => $shieki,
				     negation       => $negation ^ 1,
				     level          => $level,
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
# SYNGRAPHどうしのマッチング
# (graph_1の部分とgraph_2の全体)
#
sub syngraph_matching {
    my ($this, $graph_1, $nodebp_1, $graph_2, $nodebp_2, $body_hash, $matching_option) = @_;
    
    my @types = qw(fuzoku case kanou sonnkei ukemi shieki negation);
    my $matchnode_score = 0;
    my $matchnode_1;
    my $matchnode_2;
    my $matchnodenum1;
    my $matchnodenum2;
    my $matchnode_unmatch;
    my $matchnode_unmatch_num = @types;
    
    my $result;

    # BP内でマッチするノードを探す
    my $nodenum1 = -1;
    foreach my $node_1 (@{$graph_1->[$nodebp_1]}) {
	$nodenum1++;

	# スコアが低いものは調べない。
        next if ($node_1->{score} < $matchnode_score);

	my $nodenum2 = -1;
        foreach my $node_2 (@{$graph_2->[$nodebp_2]}) {
	    $nodenum2++;
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
		
		# 付属語、要素の違いのチェック
		my $unmatch;
		my $unmatch_num;
		foreach my $type (@types) {
		    if ($node_1->{$type} ne $node_2->{$type}) {
			$unmatch->{$type} = {graph_1 =>$node_1->{$type}, graph_2 =>$node_2->{$type}};
			$unmatch_num +=1;
		    }
		}

		# スコアが大きいペアを採用。同じスコアならば重みの大きいものを、重みが同じならば要素の違いが少ないものを。
		if ($matchnode_score < $score
		    or ($matchnode_1->{weight} + $matchnode_2->{weight} < $node_1->{weight} + $node_2->{weight})
		    or ($matchnode_1->{weight} + $matchnode_2->{weight} == $node_1->{weight} + $node_2->{weight}
			and $matchnode_unmatch_num > $unmatch_num)) {
		    $matchnode_score = $score;
		    $matchnode_1 = $node_1;
		    $matchnode_2 = $node_2;
		    $matchnodenum1 = $nodenum1;
		    $matchnodenum2 = $nodenum2;
		    $matchnode_unmatch = $unmatch;
		    $matchnode_unmatch_num = $unmatch_num;
		}
	    }		    
	}
    }
    
    # BPがマッチしない
    if ($matchnode_score == 0){
	$result->{$nodebp_2}{unmatch} = "no_matchnode";
	$this->{matching} = 'unmatch';
	return $result;
    }
    
    # BPがマッチした
    # 対応する基本句番号
    my $matchbp_1 = join(',', ($matchnode_1->{matchbp} ? sort (keys %{$matchnode_1->{matchbp}}, $nodebp_1) : ($nodebp_1)));
    my $matchbp_2 = join(',', ($matchnode_2->{matchbp} ? sort (keys %{$matchnode_2->{matchbp}}, $nodebp_2) : ($nodebp_2)));
    $result->{$nodebp_2}{matchbp1} = $matchbp_1;
    $result->{$nodebp_2}{matchbp2} = $matchbp_2;
    # マッチしたノードの情報の居場所
    $result->{$nodebp_2}{nodedata1} = "$nodebp_1-$matchnodenum1";
    $result->{$nodebp_2}{nodedata2} = "$nodebp_2-$matchnodenum2";
    # マッチのスコア,素性の違い
    $result->{$nodebp_2}{score} = $matchnode_score;
    foreach my $type (keys %{$matchnode_unmatch}) {
	$result->{$nodebp_2}{type_unmatch}{$type} = 1;
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
		$result->{$nodebp_2}{unmatch} = "child_less";
		$this->{matching} = 'unmatch';
		return $result;
	    }
	    
	    # graph_2の各子供にマッチするgraph_1の子供を見つける
	    foreach my $child_2 (@childbp_2) {
		my $match_flag = 0;

		foreach my $child_1 (@childbp_1) {
		    # すでにgraph_2他の子とマッチしたgraph_1の子はチェックしない
		    next if ($child_1_check{$child_1});
		    
		    # 子供同士のマッチング
		    $this->{matching} = 'matching';
		    my $res = $this->syngraph_matching($graph_1, $child_1, $graph_2, $child_2, $body_hash, $matching_option);
		    next if ($this->{matching} eq 'unmatch');
	
		    foreach my $nodebp (keys %{$res}) {
			$result->{$nodebp} = $res->{$nodebp};
		    }

		    $child_1_check{$child_1} = 1;
		    $match_flag = 1;
		    last;
		}

		# マッチする子がなかったらマッチ失敗
		unless ($match_flag) {
		    $result->{$nodebp_2}{unmatch} = "child_unmatch:$graph_2->[$child_2][0]{midasi}";
		    $this->{matching} = 'unmatch';
		    return $result;
		}
	    }
	    return $result;
	}

	# graph_1に子がない場合はマッチ失敗
	else {
	    $result->{$nodebp_2}{unmatch} = "child_less";
	    $this->{matching} = 'unmatch';
	    return $result;
	}
    }

    # graph_2に子がない
    else {
	return $result;
    }
}


# 新たなSYNノードとして貼り付けてよいかどうかをチェック(headに違いがあってもgraph_2に引き継ぎ可能)
# SYNノードとしての要素を獲得
sub get_nodefac {
    my ($this, $mode, $graph1, $headbp1, $graph2, $headbp2, $mres, $option) = @_;
    my $nodefac = {};
    my $score;
    my @match;
    my @child;

    my $num;
    foreach my $matchkey (keys %{$mres}) {

	# マッチしたノード情報のありか
	my ($bp1, $nodenum1) = split(/-/, $mres->{$matchkey}{nodedata1});
	my ($bp2, $nodenum2) = split(/-/, $mres->{$matchkey}{nodedata2});

	# ★headを早く見つけることで高速化可能★odani0529
	# headでの処理
	if ($headbp2 == $matchkey) {
	    
	    if ($mode eq 'syn') {
		if ($mres->{$matchkey}{type_unmatch}) {
		    # 新たなSYNノードとして貼り付けてよいかどうかをチェック(headに違いがありgraph_2に引き継ぎ不可)
		    # headの要素を引き継ぐ
		    foreach my $type (keys %{$mres->{$matchkey}{type_unmatch}}) {
			if ($type eq 'negation') {
			    $nodefac->{$type} = 1;
			}
			else {
			    if ($graph2->[$bp2][$nodenum2]{$type}) { # 引き継げない
				$this->{matching} = 'unmatch';
				return;
			    }
			    else {
				$nodefac->{$type} = $graph1->[$bp1][$nodenum1]{$type};
			    }			    
			}
		    }
		}
	    }
	    elsif($mode eq 'MT') {
		if ($mres->{$matchkey}{type_unmatch}) {
		    # MTでアライメントをとるときはheadでの違いは否定以外はみない。
		    $nodefac->{negation} = 1 if ($mres->{$matchkey}{type_unmatch}{negation});
		}
	    }

	    # SYNノードのその他の要素
	    $nodefac->{parentbp} = $graph1->[$bp1][$nodenum1]{parentbp};
	    $nodefac->{kakari_type} = $graph1->[$bp1][$nodenum1]{kakari_type};
	}

	# その他での処理
	else {
	    # 要素の不一致ごとにスコアにペナルティーをかける
	    if ($mres->{$matchkey}{type_unmatch}) {
		foreach my $type (keys %{$mres->{$matchkey}{type_unmatch}}) {
		    # 格がなければダメ
		    if ($type eq 'case') {
			next if (!$graph1->[$bp1][$nodenum1]{$type}
				 or !$graph2->[$bp2][$nodenum2]{$type});
		    }
		    # fuzoku_cut オプションがあり、付属語に不一致があった場合はダメ
		    elsif ($type eq 'fuzoku' and $option->{fuzoku_cut}) {
			$this->{matching} = 'unmatch';
			return;			
		    }
		    $mres->{$matchkey}{score} *= $penalty->{$type};
		}
	    }
	}

	# スコア
	$score += $mres->{$matchkey}{score};
	
	# マッチした基本句
	push (@match, split(/,/, $mres->{$matchkey}{matchbp1}));

	# 関係フラグ
	$nodefac->{relation} = 1 if ($graph1->[$bp1][$nodenum1]{relation} or $graph2->[$bp2][$nodenum2]{relation});
	$nodefac->{antonym} = 1 if ($graph1->[$bp1][$nodenum1]{antonym} or $graph2->[$bp2][$nodenum2]{antonym});

	# MTのアライメント用
	if ($mode eq 'MT') {
	    my @match1 = split(/,/, $mres->{$matchkey}{matchbp1});
	    my @match2 = split(/,/, $mres->{$matchkey}{matchbp2});
	    push(@{$nodefac->{match}}, {graph_1 => \@match1, graph_2 => \@match2});
	    push(@{$nodefac->{matchpair}}, {graph_1 => $graph1->[$bp1][$nodenum1]{midasi} , graph_2 => $graph2->[$bp2][$nodenum2]{midasi}});
	    push(@{$nodefac->{matchid}}, {graph_1 => $graph1->[$bp1][$nodenum1]{id}, graph_2 => $graph2->[$bp2][$nodenum2]{id}});
	}
    }

    # SYNノードのスコア
    my $num = (keys %{$mres});
    $nodefac->{score} = $score / $num;

    # SYNノードのその他の要素
    my @match_sort = sort @match;
    foreach my $matchbp1 (@match_sort) {
	$nodefac->{midasi} .= $graph1->[$matchbp1][0]{midasi};	
	$nodefac->{weight} += $graph1->[$matchbp1][0]{weight};
	if ($graph1->[$matchbp1][0]{childbp}) {
	    foreach my $childbp1 (keys %{$graph1->[$matchbp1][0]{childbp}}) {
		push (@child, $childbp1) unless grep($childbp1 eq $_, @match);
	    }
	}
	$nodefac->{matchbp}{$matchbp1} = 1 unless $matchbp1 == $headbp1;
    }
    foreach my $childbp1 (@child) {
	$nodefac->{childbp}{$childbp1} = 1;
    }

    return $nodefac;
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
    my $bp = 0;
    foreach my $tag ($result->tag) {
	# knp解析結果を出力
	$ret_string .= "+ ";
	$ret_string .= $tag->{parent} ? $tag->{parent}->{id} : -1;
	$ret_string .= "$tag->{dpndtype} $tag->{fstring}\n";
	foreach my $mrph ($tag->mrph) {
	    $ret_string .= $mrph->spec;
	}

    	# SYNGRPH情報の付与
	$ret_string .= "$syngraph_string->[$bp]";
	$bp++;
    }
    $ret_string .= "EOS\n";

    return $ret_string;
}


sub make_log {
    my ($this, $graph1, $graph2, $mid, $mres) = @_;
    my $result;
    
    # synid, expression1, expression2
    my ($synid, $expression2) = split(/,/, $mid);
    my ($expression1) = $synid =~ /s\d+:([^\/]+)/;

    # expression_orig, loglog
    my $expression_orig;
    my $loglog;
    foreach (sort {$a <=> $b} keys %{$mres}) {
	my ($bp1, $num1) = split(/-/, $mres->{$_}{nodedata1});
	my ($bp2, $num2) = split(/-/, $mres->{$_}{nodedata2});
	$expression_orig .= $graph1->[$bp1][$num1]{midasi};
	
	# マッチした表現からDBの中の表現まで
	my $tmp2;
	if ($graph2->[$bp2][$num1]{log}) {
	    my @array = split(/\n/, $graph2->[$bp2][$num2]{log});
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
	if ($graph1->[$bp1][$num1]{log}) {
	    foreach (split(/\n/, $graph1->[$bp1][$num1]{log})) {
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

sub st_make_log {
    my ($this, $graph1, $graph2, $tmid, $mres) = @_;
    my $result;
    
    # expression_orig
    my $expression_orig;
    my $expression_exam;
    my $id_orig;
    my $id_exam;
    foreach (sort {$a <=> $b} keys %{$mres}) {
	my ($bp1, $num1) = split(/-/, $mres->{$_}{nodedata1});
	my ($bp2, $num2) = split(/-/, $mres->{$_}{nodedata2});
	
	# マッチした表現
	$expression_orig .= $graph1->[$bp1][$num1]{midasi};
	$expression_exam .= $graph2->[$bp2][$num2]{midasi};

	# マッチしたノードのID
	$id_orig .= " + " if ($id_orig);
	$id_orig .="<$graph1->[$bp1][$num1]{id}>";
	foreach (('fuzoku', 'negation', 'kanou', 'sonnkei', 'shieki', 'ukemi', 'case')) {
	    if ($graph1->[$bp1][$num1]{$_}) {
		if ($_ eq 'fuzoku' or $_ eq 'case') {
		    $id_orig .= "<$_:$graph1->[$bp1][$num1]{$_}>";
		}
		else {
		    $id_orig .= "<$_>";
		}
	    }
	}
	$id_exam .= " + " if ($id_exam);
	$id_exam .="<$graph2->[$bp2][$num2]{id}>";
	foreach (('fuzoku', 'negation', 'kanou', 'sonnkei', 'shieki', 'ukemi', 'case')) {
	    if ($graph2->[$bp2][$num2]{$_}) {
		if ($_ eq 'fuzoku' or $_ eq 'case') {
		    $id_exam .= "<$_:$graph2->[$bp2][$num2]{$_}>";
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
	foreach my $node (@{$syngraph->[$bp_num]}) { # ノード単位
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
	foreach my $node (@{$syngraph->[$bp_num]}) { # ノード単位

	    # ノードの対応する基本句番号
	    my $matchbp;
	    foreach (sort {$a <=> $b} ($node->{matchbp} ? (keys %{$node->{matchbp}}, $bp_num) : ($bp_num))) {
		$matchbp .= !defined $matchbp ? "$_" : ",$_";
	    }

	    unless (grep($matchbp eq $_, keys %$res)) {

		# 親
		my $parent;
		if ($syn_bp->{$node->{parentbp}}) {
		    foreach my $parentbp (keys %{$syn_bp->{$node->{parentbp}}}) {
			# 親ノードとして正しいかチェック
			my $flag;
			foreach my $a (split(/,/, $parentbp)) {
			    foreach my $b (split(/,/, $matchbp)) {
				if ($a == $b) {
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
		    $parent = $node->{parentbp};
		}

		# !!行の出力を格納
		$res->{$matchbp} = "!! $matchbp $parent$node->{kakari_type} <見出し:$node->{midasi}>";
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

    # !行の出力を格納
    $string = "! $bp <SYNID:$node->{id}><スコア:$node->{score}>";
    $string .= "<反義語>" if ($node->{antonym});
    $string .= "<上位語>" if ($node->{relation});
    $string .= "<下位語数:$node->{hypo_num}>" if ($node->{hypo_num});
    $string .= "<否定>" if ($node->{negation});
    $string .= "<可能>" if ($node->{kanou});
    $string .= "<尊敬>" if ($node->{sonnkei});
    $string .= "<受身>" if ($node->{ukemi});
    $string .= "<使役>" if ($node->{shieki});

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

    return &decode('utf8', $value);
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
	    my $nodename;
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

	    next if ($#{$nodename} < 0);

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


1;
