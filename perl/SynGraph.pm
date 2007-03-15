package SynGraph;

# $Id$

use utf8;
use strict;
use Encode;
use KNP;
use BerkeleyDB;
use Storable qw(freeze thaw);
use MLDBM qw(BerkeleyDB::Hash Storable);


# データ構造の例
#
# '今日は雨だ' => ARRAY(0xa201614)
#    0  ARRAY(0xa201680)
#       0  HASH(0xa201620)
#          'fuzoku' => 'は'
#          'id' => '今日'
#          'origbp' => 0
#          'score' => 1
#          'weight' => 1
#       1  HASH(0xa45d800)
#          'fuzoku' => 'は'
#          'id' => 's1090本日/ほんじつ:1/1:1/1:1/1'
#          'score' => 0.99
#          'weight' => 1
#       2  HASH(0xa487218)
#          'fuzoku' => 'は'
#          'id' => 'r375AMB(日/ひ)'
#          'relation' => 1
#          'score' => 0.693
#          'weight' => 1
#    1  ARRAY(0xa201788)
#       0  HASH(0xa201644)
#          'childbp' => HASH(0xa148380)
#             0 => 1
#          'fuzoku' => 'だ'
#          'id' => '雨'
#          'origbp' => 1
#          'score' => 1
#          'weight' => 1
#       1  HASH(0xa45d860)
#          'childbp' => HASH(0xa2011a0)
#             0 => 1
#          'fuzoku' => 'だ'
#          'id' => 'r375雨/あめ:1/1:1/1:2/3'
#          'score' => 0.99
#          'weight' => 1



#
# 定数
#

# 同義語のペナルティ
my $synonym_penalty = 0.99;
# 上位・下位のペナルティ
my $relation_penalty = 0.7;
# 反義語のペナルティ
my $antonym_penalty = 0.8;

our $penalty = {};
# 付属語の違いによるペナルティ
$penalty->{fuzoku} = 1.0;
# 格の違いによるペナルティ
$penalty->{case} = 0.3;
# 可能表現の違いによるペナルティ
$penalty->{kanou} = 0.8;
# 尊敬表現の違いによるペナルティ
$penalty->{sonnkei} = 1;
# 受身表現の違いによるペナルティ
$penalty->{ukemi} = 0.3;
# 使役表現の違いによるペナルティ
$penalty->{shieki} = 0.3;
# 否定・反義語のフラグの違いによるペナルティ
$penalty->{reversal} = 0.3;
# ノード登録のしきい値
my $regnode_threshold = 0.5;


# 無視する単語のリスト(IREX用)
my @stop_words;
@stop_words = qw(記事 関する 述べる 含める 探す 場合 含む 報道 言及 関連 議論 つく 具体 的だ 良い もの 物);



#
# コンストラクタ
#
sub new {
    my ($this, $option) = @_;

    # knp option
    my @knpoptions = ('-tab');

    push @knpoptions, '-case2' if $option->{case};
    push @knpoptions, '-postprocess' if $option->{postprocess};

    my $knpoption = join(' ', @knpoptions);

    $this = {
        mode       => '',
        regnode    => '',
        syndata    => {},
        synhead    => {},
        synparent  => {},
        synantonym  => {},
        filehandle => undef,
        db_type    => '',
        db_name    => '',
        db_table   => '',
        dbh        => undef,
        sth        => undef,
        st_head    => {},
        st_data    => {},
        tm_sg      => {},
	knp        => new KNP(-Option => $knpoption),
    };
    
    bless $this;

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
    my ($this, $input, $ref, $sid, $regnode_option, $matching_option) = @_;

    # 入力がKNP結果の場合
    if (ref $input eq 'KNP::Result') {
        # 木を作る
        $this->make_tree($input, $ref);
    }
    # 入力がXMLデータの場合(MT用)
    elsif (ref $input eq 'HASH' or $input =~ /^\s*<i_data/) {
        $this->_read_xml($input, $ref, $sid);
    }
    # それ以外はテキストデータとして処理する
    else {
        # パースする
#        my $knp = new KNP;
        my $knp_result = $this->{knp}->parse($input);
        $knp_result->set_id($sid);
        # 木を作る
        $this->make_tree($knp_result, $ref);
    }

    # 各BPにSYNノードを付けていってSYNGRAPHを作る
   if ($ref->{$sid}) {
       for (my $bp_num = 0; $bp_num < @{$ref->{$sid}}; $bp_num++) {
           $this->make_bp($ref, $sid, $bp_num, $regnode_option, $matching_option); 
	}
   }
}


#
# 初期SYNGRAPHを作成
#
sub make_tree {
    my ($this, $knp_result, $tree_ref) = @_;
    my $sid = $knp_result->id;

    my @keywords = $this->_get_keywords($knp_result);

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
            # 基本ノード登録（ここではregnode_optionは関係ない）
            $this->_regnode({ref         => $tree_ref,
                             sid         => $sid,
                             bp          => $bp_num,
                             id          => $node->{name},
                             fuzoku      => $node->{fuzoku},
			     midasi      => $node->{midasi},
                             childbp     => $node->{child},
			     parentbp    => $node->{parent},
			     kakari_type => $node->{kakari_type},
			     case        => $node->{case},
                             origbp      => $bp_num,
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
    my ($this, $ref, $sid, $bp, $regnode_option, $matching_option) = @_;

    #このbpについている基本ノード、SYNノードについて調べる
    foreach my $node (@{$ref->{$sid}->[$bp]}) {
        next if ($node->{weight} == 0);

        if ($node->{id} and $this->{synhead}->{$node->{id}}) {
            foreach my $mid (@{$this->{synhead}->{$node->{id}}}) {
                # SYNIDが同じものは調べない
                my $synid1 = (split(/,/, $sid))[0];
                my $synid2 = (split(/,/, $mid))[0];
                next if ($synid1 eq $synid2);

                my $headbp = @{$this->{syndata}->{$mid}} - 1;

# 		# マッチ調べる（SYNモードではpa_matching行わない）
		my $result = $this->syngraph_matching('SYN', $ref->{$sid}, $bp, $this->{syndata}->{$mid}, $headbp);
		next if ($result eq 'unmatch');

# 		my $result = $this->approximate_matching($ref->{$sid}, $bp, $this->{syndata}->{$mid}, $headbp);
# 		next if ($result eq 'unmatch');
# 		if ($matching_option->{pa_matching_old}) {
# 		    my $kaisyou = $this->pa_matching_old($result->{NODE}, $headbp);
# 		    foreach my $bp (keys %{$kaisyou}) {
# 			$result->{NODE}->{$bp}->{kaisyou} = $kaisyou->{$bp};
# 		    }
# 		}
		
# 		$this->calc_sim($result, 'SYN', $headbp);
# 		next if ($result->{unmatch});

		$this->_regnode({ref            => $ref,
				 sid            => $sid,
				 bp             => $bp,
				 id             => $synid2,
				 fuzoku         => $result->{SYN}->{fuzoku},
				 midasi         => $result->{SYN}->{midasi},
				 matchbp        => $result->{SYN}->{matchbp},
				 childbp        => $result->{SYN}->{childbp},
				 parentbp       => $result->{SYN}->{parentbp},
				 kakari_type    => $result->{SYN}->{kakari_type},
				 case           => $result->{SYN}->{case},
				 kanou          => $result->{SYN}->{kanou},
				 sonnkei        => $result->{SYN}->{sonnkei},
				 ukemi          => $result->{SYN}->{ukemi},
				 shieki         => $result->{SYN}->{shieki},
				 negation       => $result->{SYN}->{reversal},
				 level          => $result->{SYN}->{level}, 
				 score          => $result->{CALC}->{score} * $synonym_penalty,
				 weight         => $result->{SYN}->{weight},
				 regnode_option => $regnode_option});
            }
        }
    }
}


#
# BPにIDを付与する (部分木用)
#
sub st_make_bp {
    my ($this, $ref, $sid, $bp, $max_tm_num, $option, $matching_option) = @_;

    foreach my $node (@{$ref->{$sid}->[$bp]}) {
        next if ($node->{weight} == 0);

	my %count_pattern;
        if ($node->{id} and $this->{st_head}->{$node->{id}}) {
            foreach my $stid (@{$this->{st_head}->{$node->{id}}}) {
                my $headbp = $this->{st_data}->{$stid}->{head};
                my $tmid = $this->{st_data}->{$stid}->{tmid};
                my %body;
                map {$body{$_} = 1} split(" ", $this->{st_data}->{$stid}->{body});

                # TMのSYNGRAPHを取得
                unless ($this->{tm_sg}->{$tmid}) {
                    $this->db_retrieve($this->{tm_sg}, [$tmid]);
                }
                
		# マッチ調べる
		my $result = $this->syngraph_matching('Matching', $ref->{$sid}, $bp, $this->{tm_sg}->{$tmid}, $headbp,
						      \%body, $matching_option);

		next if ($result eq 'unmatch');

#		my $result = $this->approximate_matching($ref->{$sid}, $bp, $this->{tm_sg}->{$tmid}, $headbp, \%body, $headbp);
#		next if ($result eq 'unmatch');
#		if ($matching_option->{pa_matching_old}) {
#		    my $kaisyou = $this->pa_matching_old($result->{NODE}, $headbp);
#		    foreach my $bp (keys %{$kaisyou}) {
#			$result->{NODE}->{$bp}->{kaisyou} = $kaisyou->{$bp};
#		    }
#		}
#		
#		# 類似度計算
#		my $calc = $this->calc_sim($result, 'Matching', $headbp);
#		next if ($result->{unmatch});

		# 入力の文節番号集合
		my @s_body;
		foreach my $i (@{$result->{MATCH}->{match}}) {
		    push(@s_body, @{$i->{graph_1}});
		}
		my $s_pattern = join(" ", sort(@s_body));
		next if ($max_tm_num != 0 && $count_pattern{$s_pattern} >= $max_tm_num);
		$count_pattern{$s_pattern}++;
		
		# マッチペアの出力
		if ($option->{debug}) {
		    print "matchpair\n";
		    for (my $num=0; $num<@{$result->{MATCH}->{match}}; $num++) {
			print "$num\n";
			printf "graph_1: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{graph_1}, join(',', @{$result->{MATCH}->{match}->[$num]->{graph_1}}), $result->{MATCH}->{matchid}->[$num]->{graph_1};
		    printf "graph_2: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{graph_2}, join(',', @{$result->{MATCH}->{match}->[$num]->{graph_2}}), $result->{MATCH}->{matchid}->[$num]->{graph_2};
		    }

#		    print "log\n";
#		    print "graph_1\n";
#		    print "*\n";
#		    foreach $num (@{$result->{MATCH}->{match}}) {
#			print "@{$result->{GRAPH}->{graph_1}->[$num]}";
			
#		    }
		}
		
		my $newid =
		    # シソーラス、反義語データベースは使用しない
		    $this->_regnode({ref            => $ref,
				     sid            => $sid,
				     bp             => $bp,
				     id             => $stid,
				     fuzoku         => $result->{SYN}->{fuzoku},
				     midasi         => $result->{SYN}->{midasi},
				     matchbp        => $result->{SYN}->{matchbp},
				     childbp        => $result->{SYN}->{childbp},
				     parentbp       => $result->{SYN}->{parentbp},
				     kakari_type    => $result->{SYN}->{kakari_type},
				     case           => $result->{SYN}->{case},
				     kanou          => $result->{SYN}->{kanou},
				     sonnkei        => $result->{SYN}->{sonnkei},
				     ukemi          => $result->{SYN}->{ukemi},
				     shieki         => $result->{SYN}->{shieki},
				     negation       => $result->{SYN}->{negation},
				     level          => $result->{SYN}->{level}, 
				     score          => $result->{CALC}->{score} * $synonym_penalty,
				     weight         => $result->{SYN}->{weight}
				     # regnode_option => $regnode_option # 反義語、上位語を張り付けるかどうか
				     });

		$newid->{matchid}   = $result->{MATCH}->{matchid} if ($newid);
		$newid->{match}     = $result->{MATCH}->{match} if ($newid);
		$newid->{matchpair} = $result->{MATCH}->{matchpair} if ($newid);

	    }
	}
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
    my ($this, $knp_result) = @_;
    my @keywords;

    # BP単位
    my $child = {};
    my $case = {};

    foreach my $tag ($knp_result->tag) {
        my @alt;
#	my @state;
        my $nodename;
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

        # 子供 child->{親のid}->{子のid}
        $child->{$tag->{parent}->{id}}->{$tag->{id}} = 1 if ($tag->{parent});

	# 親
	if ($tag->{parent}) {
	    $parent = $tag->{parent}->{id};
	}
	else {
	    $parent = -1;
	}

	# 親への係り方
	$kakari_type = $tag->dpndtype if ($tag->dpndtype);

	# 格 case->{係り元のid}->{係り先のid} = '〜格'
	# <格解析結果:書く/かく:動1:ガ/C/彼/0/0/?;ヲ/N/本/2/0/?;ニ/U/-/-/-/-;ト/U/-/-/-/-;デ/U/-/-/-/-;カラ/U/-/-/-/-;マデ/U/-/-/-/-;φ/U/-/-/-/-;時間/U/-/-/-/-;外の関係/U/-/-/-/-;ノ/U/-/-/-/-;ニツク/U/-/-/-/->

	if($tag->{fstring} =~ /\<格解析結果:(.+?):(.+?):([PC]\d+:)?(.+?)\>/) {
	    foreach my $node_case (split(/;/, $4)){
		# 要修正
		push (my @node_case_feature, split(/\//, $node_case));
		$case->{$node_case_feature[3]}->{$tag->{id}} = $node_case_feature[0] unless ($node_case_feature[3] =~ /-/);
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
#		my $tmp = {};
#		$tmp->{kanou}   = 1 if ($_ =~ /可能/);
#		$tmp->{sonnkei} = 1 if ($_ =~ /尊敬/);
#		$tmp->{shieki}  = 1 if ($_ =~ /使役/);
#		$tmp->{ukemi}   = 1 if ($_ =~ /受動/);

		$kanou   = 1 if ($_ =~ /可能/);
		$sonnkei = 1 if ($_ =~ /尊敬/);
		$shieki  = 1 if ($_ =~ /使役/);
		$ukemi   = 1 if ($_ =~ /受動/);
		
#		push (@state, $tmp);
	    }
	}
	
	# 節のレベル
	if ($tag->{fstring} =~ /<レベル:([^\s\/\">]+)/) {
	    $level .= $1;
	}

        foreach my $mrph ($tag->mrph) {
            next if ($mrph->{hinsi} eq '特殊' and $mrph->{bunrui} ne '記号');

            # 意味有
            if ($mrph->{fstring} =~ /<意味有>/) {
		# 可能動詞であれば戻す
		if ($mrph->{fstring} =~ /<可能動詞:([^\s\/\">]+)/) {
		    $nodename .= $1;
		}
		# 尊敬動詞であれば戻す
		elsif ($mrph->{fstring} =~ /<尊敬動詞:([^\s\/\">]+)/) {
		    $nodename .= $1;
		}
                # 代表表記
                elsif ($mrph->{fstring} =~ /<代表表記:([^\s\/\">]+)/) {
                    $nodename .= $1;
                }
                else {
                    $nodename .= $mrph->{genkei};
                }
		
                # ALT
                if (my @tmp = ($mrph->{fstring} =~ /(<ALT.+?>)/g)) {
		    foreach (@tmp){
			# 可能動詞であれば戻す
			if ($_ =~ /可能動詞:([^\s\/\">]+)/) {
			    push(@alt,$1);
			}
			# 尊敬動詞であれば戻す
			elsif ($_ =~ /尊敬動詞:([^\s\/\">]+)/) {
			    push(@alt,$1);
			}
			# 代表表記
			elsif ($_ =~ /代表表記:([^\s\/\">]+)/){
			    push(@alt,$1);
			}
		    }
                }
#                 # コンパイル時はALTは使わない場合
#                 if ($this->{mode} eq 'compile' and @alt > 0) {
#                     undef @alt;
#                 }
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
	if ($child->{$tag->{id}}) {
	    foreach my $childbp (keys %{$child->{$tag->{id}}}) {
		if ($case->{$childbp}->{$tag->{id}}) {
		    foreach my $parentnode (@{$keywords[$childbp]}) {
			$parentnode->{case} = $case->{$childbp}->{$tag->{id}};
		    }
		}
	    }
	}
	push(@{$keywords[$tag->{id}]}, \%tmp);
	
	# ALTの処理(意味有が1形態素と仮定)
	if (@alt) {
	    foreach my $alt_key (@alt) {
		# 表記が同じものは無視
		next if (grep($alt_key eq $_->{name}, @{$keywords[$tag->{id}]}));
		# 登録
		my %tmp2;
		$tmp2{name}       = $alt_key;
		$tmp2{fuzoku}     = $tmp{fuzoku};
		$tmp2{midasi}     = $tmp{midasi};
		$tmp2{kanou}      = $tmp{kanou} if ($tmp{kanou});
		$tmp2{sonnkei}    = $tmp{sonnkei} if ($tmp{sonnkei});
		$tmp2{ukemi}      = $tmp{ukemi} if ($tmp{ukemi});
		$tmp2{shieki}     = $tmp{shieki} if ($tmp{shieki});
		$tmp2{negation}   = $tmp{negation} if ($tmp{negation});                
		$tmp2{level}      = $tmp{level} if ($tmp{level});
		$tmp2{child}      = $tmp{child} if ($tmp{shild});
		$tmp{parent}      = $tmp{parent} if ($tmp{parent});
		$tmp{kakari_type} = $tmp{kakari_type} if ($tmp{kakari_type});
		$tmp2{case}     = $tmp{case} if ($tmp{case});
		push(@{$keywords[$tag->{id}]}, \%tmp2);
	    }
	}
    }
    
    return @keywords;
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
    my $org_num = -1;
    my $key_num = 0;
    my $child = {};
    my $bp_table = {};
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

        # BP番号のテーブル
        $bp_table->{$org_num} = $key_num;

        # 子供
        $child->{$phrase->{dpnd}}->{$org_num} = 1 if ($phrase->{dpnd} != -1);

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

        $key_num++;
    }
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
    my $antonym               = $args_hash->{antonym};
    my $wnum                  = $args_hash->{wnum};
    my $regnode_option        = $args_hash->{regnode_option};

    # コンパイルでは完全に一致する部分にはIDを付与しない
    return if ($this->{mode} eq 'repeat' and $bp == @{$ref->{$sid}} - 1 and !$childbp);

    # スコアが小さいIDは登録しない
    if ($score >= $regnode_threshold or ($this->{mode} =~ /irex/ and $weight == 0)) {
        # 既にそのIDが登録されていないかチェック
        if ($ref->{$sid}->[$bp]) {
            foreach my $i (@{$ref->{$sid}->[$bp]}) {
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
                    }
                    return;
                }

                return if ($id eq (split(/,/, $sid))[0]);
            }
        }

        my $newid = {};
        $newid->{id} = $id;
        $newid->{fuzoku} = $fuzoku if ($fuzoku);
	$newid->{midasi} = $midasi if ($midasi);
        foreach my $c (keys %{$childbp}) {
            $newid->{childbp}->{$c} = 1;
        }
	$newid->{parentbp} = $parentbp if ($parentbp);
	$newid->{kakari_type} = $kakari_type if ($kakari_type);
	$newid->{case} = $case if ($case);
        if ($matchbp) {
            foreach my $m (keys %{$matchbp}) {
                $newid->{matchbp}->{$m} = 1 if ($m != $bp);
            }
        }
        $newid->{origbp}   = $args_hash->{origbp} if (exists $args_hash->{origbp});
        $newid->{kanou}    = $kanou if ($kanou);
        $newid->{sonnkei}  = $sonnkei if ($sonnkei);
	$newid->{ukemi}    = $ukemi if ($ukemi);
	$newid->{shieki}   = $shieki if ($shieki);
	$newid->{negation} = $negation if ($negation);
        $newid->{level}    = $level if ($level);
        $newid->{score}    = $score;
        $newid->{weight}   = $weight;
        $newid->{relation} = $relation if ($relation);
        $newid->{wnum}     = $wnum if($wnum);
        $newid->{antonym}  = $antonym if ($antonym);
        push(@{$ref->{$sid}->[$bp]}, $newid);

	if ($regnode_option->{relation}){
	    # 上位IDがあれば登録（ただし、上位語の上位語や、反義語の上位語は登録しない。）	
	    if ($this->{mode} ne 'compile' and $this->{synparent}->{$id} and $relation != 1 and $antonym != 1) {
		foreach my $pid (keys %{$this->{synparent}->{$id}}) {
		    $this->_regnode({ref            => $ref,
				     sid            => $sid,
				     bp             => $bp,
				     id             => $pid,
				     fuzoku         => $fuzoku,
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
				     relation       => 1});
		}
	    }
	}

	if ($regnode_option->{antonym}){
	    # 反義語があれば登録（ただし、上位語の反義語や、反義語の反義語は登録しない。）
	    if ($this->{mode} ne 'compile' and $this->{synantonym}->{$id} and $antonym != 1 and $relation != 1) {
		foreach my $pid (keys %{$this->{synantonym}->{$id}}) {
		    $this->_regnode({ref            => $ref,
				     sid            => $sid,
				     bp             => $bp,
				     id             => $pid,
				     fuzoku         => $fuzoku,
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
				     score          => $score * $antonym_penalty,
				     weight         => $weight,
				     regnode_option => $regnode_option,
				     antonym        => 1});
		}
	    }
	}

        # head登録（末尾のノードのidが変わったときの対処、コンパイル用）
        if ($this->{mode} eq 'repeat' and
            $newid->{id} and
            $bp == @{$ref->{$sid}} - 1 and
            !grep($sid eq $_, @{$this->{synhead}->{$newid->{id}}})) {
            push(@{$this->{synhead}->{$newid->{id}}}, $sid);
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
    my ($this, $mode, $graph_1, $headbp_1, $graph_2, $headbp_2, $body_hash, $matching_option) = @_;
    
    # SYNGRAPHの近似マッチング
    my $result = $this->approximate_matching($graph_1, $headbp_1, $graph_2, $headbp_2, $body_hash);
    return 'unmatch' if ($result eq 'unmatch');

    # 述語項構造単位の違いの解消
    if ($matching_option->{pa_matching} or $mode ne 'SYN'){
	$this->pa_matching($result, $headbp_2);
    }

#    if ($matching_option->{pa_matching_old}){
#	my $kaisyou = $this->pa_matching_old($result->{NODE}, $headbp_2);
#	foreach my $bp (keys %{$kaisyou}) {
#	    $result->{NODE}->{$bp}->{kaisyou} = $kaisyou->{$bp};
#	}
#    }

    # 類似度計算
    $this->calc_sim($result, $mode, $headbp_2);

#    my $calc = $this->calc_sim($mode, $result->{NODE}, $headbp_2, $headbp_2);
#    return 'unmatch' if ($calc eq 'unmatch');
#    $result->{CALC} = $calc;

    if ($result->{unmatch}) {
	return 'unmatch';
    }
    else {
	return $result;
    }
}

#
# SYNGRAPHどうしの近似マッチング
# (graph_1が部分、graph_2が全体)
# BPのマッチを調べて、マッチすれば子供に対して再帰的に呼び出す
sub approximate_matching {
    my ($this, $graph_1, $nodebp_1, $graph_2, $nodebp_2, $body_hash) = @_;
    my $result;

    my @types = qw(fuzoku case kanou sonnkei ukemi shieki reversal);
    my $matchnode_score = 0;
    my $matchnode_1;
    my $matchnode_2;
    my $matchnode_unmatch;
    my $matchnode_unmatch_num = @types;
    
    # BP内でマッチするノードを探す
    foreach my $node_1 (@{$graph_1->[$nodebp_1]}) {
        next if ($node_1->{score} < $matchnode_score);
        foreach my $node_2 (@{$graph_2->[$nodebp_2]}) {
            if ((!defined $body_hash or &st_check($node_2, $body_hash))
		and $node_1->{id} eq $node_2->{id} 
		and !($node_1->{relation} and $node_2->{relation})
		and !($node_1->{antonym} and $node_2->{antonym})) {

		# スコア
                my $score = $node_1->{score} * $node_2->{score};
		
#                if ($matchnode_score < $score 
#		    or ($matchnode_score == $score 
#			and ($matchnode_1->{weight} + $matchnode_2->{weight} =< $node_1->{weight} + $node_2->{weight}))) {
		
		next if ($matchnode_score > $score 
			 or ($matchnode_score == $score 
			     and ($matchnode_1->{weight} + $matchnode_2->{weight} > $node_1->{weight} + $node_2->{weight})));
		
		# 付属語、要素の違いのチェック
		my $unmatch;
		my $unmatch_num;
		foreach my $type (@types) {
		    if ($type eq 'reversal') {
			if ($node_1->{negation} ^ $node_2->{negation} ^ $node_1->{antonym} ^ $node_2->{antonym}) {
			    $unmatch->{$type} = 1;
			    $unmatch_num +=1;			    
			}
		    }
		    else {
			if ($node_1->{$type} ne $node_2->{$type}) {
			    $unmatch->{$type} = {graph_1 =>$node_1->{$type}, graph_2 =>$node_2->{$type}};
			    $unmatch_num +=1;
			}
		    }
		}
#		    # レベル
#		    if ($node_1->{level} ne $node_2->{level}) {
#			if ($node_1->{level}) {
#			    $level_unmatch = $node_1->{level};
#			}
#		    }

		next if ($matchnode_score == $score 
			 and ($matchnode_1->{weight} + $matchnode_2->{weight} == $node_1->{weight} + $node_2->{weight})
			 and $matchnode_unmatch_num < $unmatch_num);
		
		$matchnode_score = $score;
		$matchnode_1 = $node_1;
		$matchnode_2 = $node_2;
		$matchnode_unmatch = $unmatch;
		$matchnode_unmatch_num = $unmatch_num;
	    }		    
	}
    }
    
    
    # BPがマッチしない
    return 'unmatch' if ($matchnode_score == 0);
    
    # BPがマッチした
    $result->{GRAPH}->{graph_1} = $graph_1;
    $result->{GRAPH}->{graph_2} = $graph_2;
    $result->{NODE}->{$nodebp_2}->{score} = $matchnode_score;
    $result->{NODE}->{$nodebp_2}->{weight} = $matchnode_2->{weight};
    $result->{NODE}->{$nodebp_2}->{matchid} = $matchnode_2->{id};
    foreach my $c (keys %{$matchnode_2->{childbp}}){
	$result->{NODE}->{$nodebp_2}->{childbp}->{$c} = 1;
    }
    $result->{NODE}->{$nodebp_2}->{unmatch} = $matchnode_unmatch;;
#    $result->{unmatch}->[$nodebp_2]->{level}    = $level_unmatch if ($level_unmatch);
    
    $result->{SYN}->{weight} = $matchnode_1->{weight};
    $result->{SYN}->{midasi} = $matchnode_1->{midasi};
    $result->{SYN}->{parentbp} = $matchnode_1->{parentbp};
    $result->{SYN}->{kakari_type} = $matchnode_1->{kakari_type};
    if ($matchnode_1->{matchbp}) {
	foreach my $m (keys %{$matchnode_1->{matchbp}}) {
	    $result->{SYN}->{matchbp}->{$m} = 1;
	}
    }
    $result->{SYN}->{matchbp}->{$nodebp_1} = 1;  # 自分もいれておく

    # マッチの対応
    my @match_1 = sort keys %{$result->{SYN}->{matchbp}};
    my @match_2;
    if ($matchnode_2->{matchbp}) {
	@match_2 = sort (keys %{$matchnode_2->{matchbp}}, $nodebp_2);
    }
    else { # 後で手直しodani3/1
	@match_2 = $nodebp_2;
    }
    push(@{$result->{MATCH}->{match}}, {graph_1 => \@match_1, graph_2 => \@match_2});
    my $matchmidasi_1;
    my $matchmidasi_2;
    foreach my $matchbp_1 (@match_1) {
	$matchmidasi_1 .= $graph_1->[$matchbp_1]->[0]->{midasi};
    }
    foreach my $matchbp_2 (@match_2) {
	$matchmidasi_2 .= $graph_2->[$matchbp_2]->[0]->{midasi};
    }
    push(@{$result->{MATCH}->{matchpair}}, {graph_1 => $matchmidasi_1, graph_2 => $matchmidasi_2});
    push(@{$result->{MATCH}->{matchid}}, {graph_1 => $matchnode_1->{id}, graph_2 => $matchnode_2->{id}});    

    # $graph_2に子BPがあるかどうか
    my @childbp_2;
    if ($matchnode_2->{childbp}) {
	if (defined $body_hash) {
	    @childbp_2 = grep($body_hash->{$_}, sort keys %{$matchnode_2->{childbp}});
	}
	else {
	    @childbp_2 = keys %{$matchnode_2->{childbp}};
	}
    }
    if (@childbp_2 > 0) {
	# $graph_1に子BPがあるかどうか
	if ($matchnode_1->{childbp}) {
	    my @childbp_1 = keys %{$matchnode_1->{childbp}};
	    my %child_1_check;

	    # bの各子供にマッチするaの子供を見つける
	    return 'unmatch' if (@childbp_1 < @childbp_2);

	    foreach my $child_2 (@childbp_2) {
		my $match_flag = 0;
		foreach my $child_1 (@childbp_1) {
		    next if ($child_1_check{$child_1});

		    my $res = $this->approximate_matching($graph_1, $child_1, $graph_2, $child_2, $body_hash);
		    next if ($res eq 'unmatch');

		    foreach my $nodebp (keys %{$res->{NODE}}) {
			$result->{NODE}->{$nodebp}->{score} = $res->{NODE}->{$nodebp}->{score};
			$result->{NODE}->{$nodebp}->{weight} = $res->{NODE}->{$nodebp}->{weight};
			$result->{NODE}->{$nodebp}->{matchid} = $res->{NODE}->{$nodebp}->{matchid};
			foreach my $resc (keys %{$res->{NODE}->{$nodebp}->{childbp}}) {
			    $result->{NODE}->{$child_2}->{childbp}->{$resc} = 1;
			}
			foreach my $restype (keys %{$res->{NODE}->{$nodebp}->{unmatch}}){
			    $result->{NODE}->{$nodebp}->{unmatch}->{$restype} = $res->{NODE}->{$nodebp}->{unmatch}->{$restype}
			}
		    }
		    
		    $result->{SYN}->{weight} += $res->{SYN}->{weight};
		    $result->{SYN}->{midasi} = $res->{SYN}->{midasi} . $result->{SYN}->{midasi};
		    foreach my $m (keys %{$res->{SYN}->{matchbp}}) {
			$result->{SYN}->{matchbp}->{$m} = 1;
		    }
		    foreach my $c (keys %{$res->{SYN}->{childbp}}) {
			$result->{SYN}->{childbp}->{$c} = 1;
		    }

		    push(@{$result->{MATCH}->{matchid}}, @{$res->{MATCH}->{matchid}});
		    push(@{$result->{MATCH}->{match}}, @{$res->{MATCH}->{match}});
		    push(@{$result->{MATCH}->{matchpair}}, @{$res->{MATCH}->{matchpair}});
		    
		    $child_1_check{$child_1} = 1;
		    $match_flag = 1;
		    last;		    
		}

		unless ($match_flag) {
		    return 'unmatch';
		}
	    }
	    foreach my $child_1 (@childbp_1) {
		$result->{SYN}->{childbp}->{$child_1} = 1 unless ($child_1_check{$child_1});
	    }

	    return $result;
	}
	# Aに子BPがない
	else {
	    return 'unmatch';
	}
    }
    # Bに子BPがない
    else {
	# Aに子BPがある
	if ($matchnode_1->{childbp}) {
	    foreach my $c (keys %{$matchnode_1->{childbp}}) {
		$result->{SYN}->{childbp}->{$c} = 1;
	    }
	}

	return $result;
    }
}

sub pa_matching {
    my ($this, $result, $bp) = @_;
    my $match_tree = $result->{NODE};

    # 子供がいない
    return if (!defined $match_tree->{$bp}->{childbp});

    # 子供がいる
    foreach my $childbp (keys %{$match_tree->{$bp}->{childbp}}) {
	$this->pa_matching($result, $childbp);
    }

    return if (!defined $match_tree->{$bp}->{unmatch});

    # 受身表現
    # 子供に格の不一致が２つあれば受身表現の不一致を解消する。
    if ($match_tree->{$bp}->{unmatch}->{ukemi}) {
	my $check;
	my @key_child;
    	
	foreach my $childbp (keys %{$match_tree->{$bp}->{childbp}}) {
	    if ($match_tree->{$childbp}->{unmatch}->{case}) {
		if ($match_tree->{$childbp}->{unmatch}->{case}->{graph_1} and $match_tree->{$childbp}->{unmatch}->{case}->{graph_2}){
		    $check += 1;
		    push @key_child,$childbp;
		    last if ($check==2);
		}
	    }
	}
	if ($check==2){
	    $result->{NODE}->{$bp}->{dissolve}->{ukemi} = 1;
	    foreach my $childbp (@key_child) {
		$result->{NODE}->{$childbp}->{dissolve}->{case} = 1;
	    }
	}
    }

    # 使役表現
    # 子供に格の不一致があって、使役表現の側が「ニ格」、もう一方が「ガ格」
    if ($match_tree->{$bp}->{unmatch}->{shieki}) {
	my $shieki;
	my $non_shieki;
    	my $check;
	my $key_child;
	
	if ($match_tree->{$bp}->{unmatch}->{shieki}->{graph_1}) {
	    $shieki = 'graph_1';
	    $non_shieki = 'graph_2';
	}
	foreach my $childbp (keys %{$match_tree->{$bp}->{childbp}}) {
	    if ($match_tree->{$childbp}->{unmatch}->{case}) {
		if ($match_tree->{$childbp}->{unmatch}->{case}->{$shieki} eq 'ニ' 
		    and $match_tree->{$childbp}->{unmatch}->{case}->{$non_shieki} eq 'ガ'){
		    $check = 1;
		    $key_child = $childbp;
		    last;
		}
	    }
	}
	if ($check){
	    $result->{NODE}->{$bp}->{dissolve}->{shieki} = 1;
	    $result->{NODE}->{$key_child}->{dissolve}->{case} = 1;
	}
    }

    # 述語が反義な表現
    # 子供に格の不一致が２つあれば述語の反義の不一致を解消する
    if ($match_tree->{$bp}->{unmatch}->{reversal}) {
	my $check;
	my @key_child;
    	
	foreach my $childbp (keys %{$match_tree->{$bp}->{childbp}}) {
	    if ($match_tree->{$childbp}->{unmatch}->{case}) {
		if ($match_tree->{$childbp}->{unmatch}->{case}->{graph_1} and $match_tree->{$childbp}->{unmatch}->{case}->{graph_2}){
		    $check += 1;
		    push @key_child, $childbp;
		    last if ($check==2);
		}
	    }
	}
	if ($check==2){
	    $result->{NODE}->{$bp}->{dissolve}->{reversal} = 1;
	    foreach my $childbp (@key_child) {
		$result->{NODE}->{$childbp}->{dissolve}->{case} = 1;
	    }
	}
    }
  
    return;
}

sub pa_matching_old {
    my ($this, $match_tree, $bp) = @_;
    my $kaisyou={};

    return $kaisyou if (!defined $match_tree->{$bp}->{childbp});

    foreach my $childbp (keys %{$match_tree->{$bp}->{childbp}}) {
	my $res = $this->pa_matching_old($match_tree,$childbp);
	foreach my $kaisyoubp (keys %{$res}) {
	    my $tyouhuku_check;
	    foreach my $type (keys %{$res->{$kaisyoubp}}) {
		$tyouhuku_check = 1 if ($kaisyou->{$kaisyoubp}->{$type} == 1);
	    }
	    next if ($tyouhuku_check == 1);
	    foreach my $type (keys %{$res->{$kaisyoubp}}) {
		$kaisyou->{$kaisyoubp}->{$type} = 1;
	    }
	}
    }

    return $kaisyou if (!defined $match_tree->{$bp}->{unmatch});

    # 受身表現
    # 子供に格の不一致が２つあれば受身表現の不一致を解消する。
    if ($match_tree->{$bp}->{unmatch}->{ukemi}) {
	my $check;
	my @key_child;
    	
	foreach my $childbp (keys %{$match_tree->{$bp}->{childbp}}) {
	    if ($match_tree->{$childbp}->{unmatch}->{case}) {
		if ($match_tree->{$childbp}->{unmatch}->{case}->{graph_1} and $match_tree->{$childbp}->{unmatch}->{case}->{graph_2}){
		    $check += 1;
		    push @key_child,$childbp;
		    last if ($check==2);
		}
	    }
	}
	if ($check==2){
	    $kaisyou->{$bp}->{ukemi} = 1;
	    foreach my $childbp (@key_child) {
		$kaisyou->{$childbp}->{case} = 1;
	    }
	}
    }

    # 述語が反義な表現
    # 子供に格の不一致が２つあれば述語の反義の不一致を解消する
    if ($match_tree->{$bp}->{unmatch}->{negation}) {
	my $check;
	my @key_child;
    	
	foreach my $childbp (keys %{$match_tree->{$bp}->{childbp}}) {
	    if ($match_tree->{$childbp}->{unmatch}->{case}) {
		if ($match_tree->{$childbp}->{unmatch}->{case}->{graph_1} and $match_tree->{$childbp}->{unmatch}->{case}->{graph_2}){
		    $check += 1;
		    push @key_child, $childbp;
		    last if ($check==2);
		}
	    }
	}
	if ($check==2){
	    $kaisyou->{$bp}->{negation} = 1;
	    foreach my $childbp (@key_child) {
		$kaisyou->{$childbp}->{case} = 1;
	    }
	}
    }

    return $kaisyou;
}

sub calc_sim {
    my ($this, $result, $mode, $headbp) = @_;
    my $matchtree = $result->{NODE};
    my $score_sum;
    my $match_num;

    foreach my $bp (keys %{$matchtree}) {
	if ($matchtree->{$bp}->{unmatch}){
	    foreach my $unmatch_type (keys %{$matchtree->{$bp}->{unmatch}}) {
		next if ($matchtree->{$bp}->{dissolve}->{$unmatch_type} == 1);
		
		if ($bp == $headbp) {
		    if ($mode eq 'SYN') {
			if ($unmatch_type eq 'reversal') {
			    # 要素引き継ぎ
			    $result->{SYN}->{$unmatch_type} = 1;
			}
			else {
			    if (!defined $matchtree->{$bp}->{unmatch}->{$unmatch_type}->{graph_2}){
				# 要素引き継ぎ
				$result->{SYN}->{$unmatch_type} = $matchtree->{$bp}->{unmatch}->{$unmatch_type}->{graph_1};
			    }
			    else {
				$result->{unmatch} = 1;
				return;
			    }
			}
		    }
		    if ($mode eq 'Matching') { # MTでアライメントをとるときはheadでの{fuzoku,case}の違いはみない。
			if ($unmatch_type eq 'case' or $unmatch_type eq 'fuzoku'){
			    next;
			}
			else {
			    $matchtree->{$bp}->{score} *= $penalty->{$unmatch_type};
			}
		    }
		}
		else {
		    if ($unmatch_type eq 'case'){
			next if (!$matchtree->{$bp}->{unmatch}->{$unmatch_type}->{graph_1} 
				 or !$matchtree->{$bp}->{unmatch}->{$unmatch_type}->{graph_2});
		    }
		    $matchtree->{$bp}->{score} *= $penalty->{$unmatch_type};
		}

	    }
	}
	if ($matchtree->{$bp}->{score}) {
	    $score_sum += $matchtree->{$bp}->{score};
	    $match_num++;
	}
    }

    if ($match_num == 0) {
	$result->{unmatch} = 1;
	return;
    }
    else{
	$result->{CALC}->{score} = $score_sum / $match_num;
	return;
    }
}

sub calc_sim_old {
    my ($this, $mode, $match_tree, $bp, $headbp) = @_;
    my $result = {};

    $result->{match_weight} = $match_tree->{$bp}->{score};
    $result->{weight} = $match_tree->{$bp}->{weight};

    if ($match_tree->{$bp}->{unmatch}){
	foreach my $unmatch_type (keys %{$match_tree->{$bp}->{unmatch}}) {
	    next if ($match_tree->{$bp}->{kaisyou}->{$unmatch_type} == 1);

	    if ($bp == $headbp) {
		if ($mode eq 'SYN') {
		    if (!defined $match_tree->{$bp}->{unmatch}->{$unmatch_type}->{graph_2}){
			# 要素引き継ぎ
			$result->{SYN}->{$unmatch_type} = $match_tree->{$bp}->{unmatch}->{$unmatch_type}->{graph_1};
		    }
		    else {
			return 'unmatch';
		    }
		}
		if ($mode eq 'Matching') { # MTでアライメントをとるときはheadでの{fuzoku,case}の違いはみない。
		    if ($unmatch_type eq 'case' or $unmatch_type eq 'fuzoku'){
			next;
		    }
		    else {
			$result->{match_weight} *= $penalty->{$unmatch_type};
		    }
		}
	    }
	    else {
		if ($unmatch_type eq 'case'){
		    next if (!$match_tree->{$bp}->{unmatch}->{$unmatch_type}->{graph_1} or !$match_tree->{$bp}->{unmatch}->{$unmatch_type}->{graph_2});
		}
		$result->{match_weight} *= $penalty->{$unmatch_type};
	    }
	}
    }
    if (defined $result->{weight}) {
	$result->{score} = $result->{match_weight} / $result->{weight};
    }
    else {
	print "error!!\n";
	$result->{score} = 0;
    }

    # 子供がいる
    if ($match_tree->{$bp}->{childbp}) {
	foreach my $cbp (keys %{$match_tree->{$bp}->{childbp}}){
	    my $res = $this->calc_sim_old($mode, $match_tree, $cbp, $headbp);
	    $result->{match_weight} += $res->{match_weight};	
	    $result->{weight} += $res->{weight};	
	    $result->{score} =$result->{match_weight} / $result->{weight};
	}
    }

    return $result;
}


################################################################################
#                                                                              #
#                          SYNGRAPHのフォーマット 関係                           #
#                                                                              #
################################################################################

sub OutputSynFormat { 
    my ($this, $result, $regnode_option, $option) = @_;

    my $syngraph = {};

    $syngraph->{graph} = {};
    $this->make_sg($result, $syngraph->{graph}, $result->id, $regnode_option);
    Dumpvalue->new->dumpValue($syngraph->{graph}) if ($option->{debug});

    # SynGraphをformat化
    $syngraph->{format} = $this->format_syngraph_new($syngraph->{graph}->{$result->id});

    # KNPと併せて出力
    print $result->comment;
    my $bp = 0;
    foreach my $bnst ($result->bnst) {
	my $knp_string;
	my $syngraph_string;

	# knp出力を格納
	$knp_string = "* ";
	if ($bnst->{parent}) {
	    $knp_string .= $bnst->{parent}->{id};	
	}
	else {
	    $knp_string .= -1;
	}
	$knp_string .= "$bnst->{dpndtype} $bnst->{fstring}\n";
	foreach my $tag ($bnst->tag) {
	    $knp_string .= "+ ";
	    if ($tag->{parent}) {
		$knp_string .= $tag->{parent}->{id};	
	    }
	    else {
		$knp_string .= -1;
	    }
	    $knp_string .= "$tag->{dpndtype} $tag->{fstring}\n";
	    foreach my $mrph ($tag->mrph) {
		$knp_string .= $mrph->spec;
	    }
	    $bp++;
	}

	# 出力
	foreach (sort (keys %{$syngraph->{format}->{key}})) {
	    if ($_ < $bp) {
		foreach (@{$syngraph->{format}->{key}->{$_}}) {
		    $syngraph_string .= "$syngraph->{format}->{$_}->{co_string}\n" 
			. "$syngraph->{format}->{$_}->{node_string}";
		}
		delete $syngraph->{format}->{key}->{$_};
	    }
	}
	printf "$knp_string$syngraph_string";
    }

    print "EOS\n";
}

sub format_syngraph_new {
    my ($this, $syngraph) = @_;
    my $result; # $result->{対応する基本句番号}->{co_string} = !!の行
                # $result->{対応する基本句番号}->{node_string} = !の行
                # $result->{key} = 基本句番号の出力順ソート列

    my $co_string; # $co_string->{対応する基本句番号} = !!の行要素のハッシュ
    my $node_string; # $node_string->{対応する基本句番号} = !の行要素のハッシュ
    my $key; #$key->{基本句番号}=1

    my $bp=0;
    foreach (@{$syngraph}) {	
	# 基本句(BP)単位
	foreach my $node (@{$_}) {
	    # ノード単位
	    # ノードの対応する基本句番号
	    my $matchbp;
	    foreach (sort (keys %{$node->{matchbp}}, $bp)){
		$matchbp .= !defined $matchbp ? "$_" : ",$_";
	    }
	    
	    my @array;
	    @array = (split/,/, $matchbp);

	    # ノードの種類
	    $key->{$matchbp} = 1 unless ($key->{matchbp});

	    # ノードのfeature列
	    $node_string->{fstring} = "<SYNID:$node->{id}><スコア:$node->{score}>";
	    $node_string->{fstring} .= "<反義語>" if ($node->{antonym});
	    $node_string->{fstring} .= "<上位語>" if ($node->{relation});
	    $node_string->{fstring} .= "<否定表現>" if ($node->{negation});

	    unless ($co_string->{$matchbp}->{fstring}) {
		$co_string->{$matchbp}->{kakari_type} = "$node->{kakari_type}";
		$co_string->{$matchbp}->{fstring} .= "<見出し:$node->{midasi}>";
		$co_string->{$matchbp}->{fstring} .= "<格解析結果:$node->{case}格>" if ($node->{case});
		$co_string->{$matchbp}->{fstring} .= "<可能表現>" if ($node->{kanou});
		$co_string->{$matchbp}->{fstring} .= "<尊敬表現>" if ($node->{sonnkei});
		$co_string->{$matchbp}->{fstring} .= "<使役表現>" if ($node->{sieki});
		$co_string->{$matchbp}->{fstring} .= "<受身表現>" if ($node->{ukemi});
	    }
	    
	    # ノード間の親子関係
	    if ($node->{childbp}) {
		foreach my $childbp (sort (keys %{$node->{childbp}})) {
		    $co_string->{$childbp}->{parent}->{$matchbp} = 1 unless ($co_string->{$childbp}->{parent}->{$matchbp});
		}
	    }
	    $result->{$matchbp}->{node_string} .= "! $matchbp $node_string->{fstring}\n";
	}
	$bp++;
    }

    $result->{key} = $this->key_sort_for_format($key);

    foreach my $num (keys %{$co_string}) {
	$result->{$num}->{co_string} = "!! $num";
	my $check;
	if ($co_string->{$num}->{parent}) {
	    foreach (keys %{$co_string->{$num}->{parent}}) {
		unless ($check){
		    $result->{$num}->{co_string} .= " $_"; 
		    $check++;
		}
		else {
		    $result->{$num}->{co_string} .= "/$_"; 
		}
	    }
	}
	elsif ($num =~ /,/) {
	    foreach (split/,/, $num) {
		if ($co_string->{$_}->{parent}) {
		    foreach (keys %{$co_string->{$_}->{parent}}) {
			next if ($num =~ /$_/);
			unless ($check){
			    $result->{$num}->{co_string} .= " $_"; 
			    $check++;
			}
			else {
			    $result->{$num}->{co_string} .= "/$_"; 
			}
		    }
		}
	    }
	    unless ($check) {
		$result->{$num}->{co_string} .= " -1";	    			
	    }
	}
	else{	    
	    $result->{$num}->{co_string} .= " -1";	    
	}
	$result->{$num}->{co_string} .= "$co_string->{$num}->{kakari_type} $co_string->{$num}->{fstring}"; 
    }
    return $result;
}

#
# SYNGRAPHの出力順に
#
sub key_sort_for_format{    
    my ($this, $key) = @_;
    my $sort_key;

    my $begin; # 先頭を格納
    my $last; # おしりを格納
    foreach (keys %{$key}) {
	my @array = (split/,/, $_);
	$last->{$array[@array-1]}->{$_} = 1;    
	$begin->{$_} = $array[0];
    }

    foreach my $num (sort (keys %{$begin})) {
	foreach (sort {$begin->{$b} <=> $begin->{$a}} keys %{$last->{$num}}) {
	    push (@{$sort_key->{$num}}, $_);
	}
    }

    return $sort_key;
}

################################################################################
#                                                                              #
#                            KNP結果の読み込み 関係                               #
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
    $syndata = 'syndata.mldbm' unless ($syndata);
    $synhead = 'synhead.mldbm' unless ($synhead);
    $synparent = 'synparent.mldbm' unless ($synparent);
    $synantonym = 'synantonym.mldbm' unless ($synantonym);

    &retrieve_mldbm($syndata, $this->{syndata});
    &retrieve_mldbm($synhead, $this->{synhead});
    &retrieve_mldbm($synparent, $this->{synparent});
    &retrieve_mldbm($synantonym, $this->{synantonym});
}


#
# 類義表現DBをtie
#
sub tie_syndb {
    my ($this, $syndata, $synhead, $synparent, $synantonym) = @_;
    $syndata = 'syndata.mldbm' unless ($syndata);
    $synhead = 'synhead.mldbm' unless ($synhead);
    $synparent = 'synparent.mldbm' unless ($synparent);
    $synantonym = 'synantonym.mldbm' unless ($synantonym);

    &tie_mldbm($syndata, $this->{syndata});
    &tie_mldbm($synhead, $this->{synhead});
    &tie_mldbm($synparent, $this->{synparent});
    &tie_mldbm($synantonym, $this->{synantonym});
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
#                               BerkeleyDB 関係                                #
#                                                                              #
################################################################################

#
# BerkeleyDBに保存
#
sub store_db {
    my ($filename, $hash_ref) = @_;
    my %hash;

    # ファイルを消して作りなおす
    my $db = tie %hash, 'BerkeleyDB::Hash', -Filename => $filename, -Flags => DB_CREATE, -Cachesize => 100000000 or die;

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
# BerkeleyDBをtie
#
sub tie_db {
    my ($filename, $hash_ref) = @_;

    my $db = tie %$hash_ref, 'BerkeleyDB::Hash', -Filename => $filename, -Flags => DB_RDONLY, -Cachesize => 100000000 or die;

    # filter setting
    $db->filter_fetch_key(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_key(sub{$_ = &encode('euc-jp', $_)});
    $db->filter_fetch_value(sub{$_ = &decode('euc-jp', $_)});
    $db->filter_store_value(sub{$_ = &encode('euc-jp', $_)});
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

    my $db = tie %$hash_ref, 'MLDBM', -Filename => $filename, -Flags => DB_CREATE or die;

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

    my $db = tie %$hash_ref, 'MLDBM', -Filename => $filename, -Flags => DB_RDONLY or die;

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


1;
