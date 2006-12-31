package Search;

# $Id$

use utf8;
use strict;
use lib qw(../perl);
use SynGraph;


#
#定数
#


#係りの一致の重み（語の一致の重みは１）
my $kakari_weight = 0.5;


#
# コンストラクタ
#
sub new {
    my ($this, $db_hash, $index_ref, $knp_option) = @_;

    $this = {
        mode         => '',
        sgh          => new SynGraph($knp_option),
        index        => [],
        ref          => {},
        thash        => {},
        tf           => {},
        df           => {},
        doclen       => {},
        matching_tmp => {},
    };
    bless $this;
    
    # DB情報
    $this->{sgh}->db_set($db_hash);

    # 類義表現DBをtie
    $this->{sgh}->tie_syndb('../syndb/syndata.mldbm', '../syndb/synhead.mldbm', '../syndb/synparent.mldbm', '../syndb/synantonym.mldbm');

    # インデックスをtie
#    $this->tie_index(@$index_ref);
    
    # dfをtie
#    &SynGraph::tie_db('df.db', $this->{df});

    # doclenをtie
#    &SynGraph::tie_db('doclen.db', $this->{doclen});

    # DBに接続
    $this->{sgh}->db_connect;

    return $this;
}


#
# デストラクタ
#
sub DESTROY {
    my ($this) = @_;

    # 類義表現DBをuntie
    $this->{sgh}->untie_syndb;

    # インデックスをuntie
    $this->untie_index;

    # DBを切断
    $this->{sgh}->db_disconnect;
}


#
# 検索
#
sub search {
    my ($this, $query, $retrieve_num, $threshold) = @_;
    my $qsid = 'query';
    $this->{ref} = {};

    # SYNGRAPHを作成
    $this->{sgh}->make_sg($query, $this->{ref}, $qsid);
    return unless ($this->{ref}->{$qsid});

    # 粗いスコア計算
    my %r_score;
    foreach my $index (@{$this->{index}}) {
        foreach my $bp (@{$this->{ref}->{$qsid}}) {
            my %max_score;
            foreach my $node (@$bp) {
                foreach my $sidscore (split(/\|/, $index->{$node->{id}})) {
                    my ($sid, $score) = split(/:/, $sidscore);
                    my $s = $score * $node->{score} * $node->{weight};
                    if ($s > $max_score{$sid}) {
                        $max_score{$sid} = $s;
                    }
                }
            }
            foreach my $sid (keys %max_score) {
                $r_score{$sid} += $max_score{$sid};
            }
        }
    }

    # 足切り
    my @candidate;
    foreach my $sid (sort {$r_score{$b} <=> $r_score{$a}} keys %r_score) {
        push(@candidate, $sid);
        last if (@candidate >= $retrieve_num);
    }

    # SYNGRAPHを取得
    $this->{sgh}->db_retrieve($this->{ref}, \@candidate);

    # 転置ハッシュを作る
    $this->{thash} = {};
    foreach my $sid (keys %{$this->{ref}}) {
        next unless ($this->{ref}->{$sid});
        for (my $bpnum = 0; $bpnum < @{$this->{ref}->{$sid}}; $bpnum++) {
            my $bp = $this->{ref}->{$sid}->[$bpnum];
            foreach my $node (@$bp) {
                $node->{bp} = $bpnum;       # 対応付けのために必要
                push(@{$this->{thash}->{$sid}->{$node->{id}}}, $node) if ($node->{id});
            }
        }
    }
    
    # 正確なスコア計算
    my %a_score;
    foreach my $csid (keys %{$this->{thash}}) {
        next if ($csid eq $qsid);
        # クエリ→用例の被覆率
        $this->{matching_tmp} = {};
        $a_score{$csid} =
            $this->matching($qsid, @{$this->{ref}->{$qsid}}-1, $csid, 0, -1);
        # 用例→クエリの被覆率
        $this->{matching_tmp} = {};
        $a_score{$csid}->{score} *=
            $this->matching($csid, @{$this->{ref}->{$csid}}-1, $qsid, 0, -1)->{score};
    }
    
    # 最終的なランキング
    my @result;
    foreach my $sid (sort {$a_score{$b}->{score} <=> $a_score{$a}->{score}} keys %a_score) {
        last if ($a_score{$sid}->{score} < $threshold);
        $a_score{$sid}->{sid} = $sid;
        push(@result, $a_score{$sid});
    }

    return @result;
}


#
# IREX用 検索
#
sub search_irex {
    my ($this, $query_array, $retrieve_num) = @_;
    my @qsids;
    my $topicid;
    my %type_weight;
    $this->{mode} = $this->{sgh}->{mode} = 'irex';
    
    # 全てのクエリのSYNGRAPHを作る
    $this->{ref} = {};
    for (my $queryid = 0; $queryid < @$query_array; $queryid++) {
        my $query = $query_array->[$queryid]->{query};
        my $type = $query_array->[$queryid]->{type};
        $topicid = $query_array->[$queryid]->{topicid} unless ($topicid);

        my $qsid = join("\t", ($topicid, $queryid, $type));
        push(@qsids, $qsid);

        # DESCRIPTIONの比率
        $type_weight{$qsid} = $type eq 'DESCRIPTION' ? 1 : 0.5;

        # SYNGRAPHを作成
        $this->{sgh}->make_sg($query, $this->{ref}, $qsid);
    }

    # 粗いスコア計算
    my %r_score;
    foreach my $index (@{$this->{index}}) {
        foreach my $qsid (@qsids) {
            foreach my $bp (@{$this->{ref}->{$qsid}}) {
                my %max_score;
                foreach my $node (@$bp) {
                    foreach my $docscore (split(/\|/, $index->{$node->{id}})) {
                        my ($docid, $score) = split(/:/, $docscore);
                        my $s = $score * $node->{score} * $node->{weight};
                        if ($s > $max_score{$docid}) {
                            $max_score{$docid} = $s;
                        }
                    }
                }
                foreach my $docid (keys %max_score) {
                    $r_score{$docid} += $max_score{$docid} * $type_weight{$qsid};
                }
            }
        }
    }
    
    # 足切り
    my @candidate;
    foreach my $docid (sort {$r_score{$b} <=> $r_score{$a}} keys %r_score) {
        if ($retrieve_num eq 'rough') {
            push(@candidate, {docid => $docid, score => $r_score{$docid}});
            last if (@candidate >= 300);
        }
        else {
            push(@candidate, $docid);
            last if (@candidate >= $retrieve_num);
        }
    }
    return @candidate if ($retrieve_num eq 'rough');

    # SYNGRAPHを取得
    $this->{sgh}->db_retrieve($this->{ref}, \@candidate);

    # 転置ハッシュを作る
    $this->{thash} = {};
    $this->{tf} = {};         # BM25の計算時に必要
    foreach my $sid (keys %{$this->{ref}}) {
        next if (grep($_ eq $sid, @qsids));
        my $docid = (split(/,/, $sid))[0];
        for (my $bpnum = 0; $bpnum < @{$this->{ref}->{$sid}}; $bpnum++) {
            my $bp = $this->{ref}->{$sid}->[$bpnum];
            foreach my $node (@$bp) {
                $node->{bp} = $bpnum;       # 対応付けのために必要
                push(@{$this->{thash}->{$sid}->{$node->{id}}}, $node) if ($node->{id});
                $this->{tf}->{$docid}->{$node->{id}} += $node->{score} if ($node->{id});
            }
        }
    }
    
    # 正確なスコア計算
    my %a_score;
    foreach my $qsid (@qsids) {
        foreach my $csid (keys %{$this->{thash}}) {
            next if ($csid eq $qsid);
            # クエリ→用例の類似度
            $this->{matching_tmp} = {};
            my $r = $this->matching($qsid, @{$this->{ref}->{$qsid}}-1, $csid, 0, -1);
            # 文書ごとに集計
            my ($docid, $bunid) = split(/,/, $csid);
            $a_score{$docid} += $r->{score} * $type_weight{$qsid};

            # ログをとる
            open(LOG, ">>irex_log_$retrieve_num.txt") or die;
            print LOG $qsid, "\t";
            print LOG 0, "\t";
            print LOG $csid, "\t";
            print LOG $r->{match_weight}+0, "\t";
            print LOG $r->{match_kakari}+0, "\n";
            close(LOG);
        }
    }
    
    # 最終的なランキング
    my @result;
    foreach my $docid (sort {$a_score{$b} <=> $a_score{$a}} keys %a_score) {
        push(@result, {docid => $docid, score => $a_score{$docid}});
        last if (@result >= 300);
    }

    return @result;
}


#
# 正確なスコア計算
#
sub matching {
    my ($this, $qsid, $qbp, $tsid, $c_ref, $k_score) = @_;
    my $result;

    # すでに計算済みの場合
    if ($this->{matching_tmp}->{$qbp} and $this->{matching_tmp}->{$qbp}->{$c_ref}) {
        return $this->{matching_tmp}->{$qbp}->{$c_ref};
    }

    # マッチング開始
    foreach my $qid (@{$this->{ref}->{$qsid}->[$qbp]}) {
        $result->{$qid}->{weight}                = $qid->{weight};
        $result->{$qid}->{kakari}                = 1 if ($qid->{weight} != 0 and $k_score != -1);

        # マッチした
        if ($qid->{id} and $this->{thash}->{$tsid}->{$qid->{id}}) {
            my $tm_result;

            foreach my $tmid (@{$this->{thash}->{$tsid}->{$qid->{id}}}) {
                $tm_result->{$tmid}->{weight}            = $result->{$qid}->{weight};
                $tm_result->{$tmid}->{kakari}            = $result->{$qid}->{kakari};
                # マッチしたものの対応付け
                my ($qmatch, $tmatch);
                my ($qorigbp, $torigbp);
		my $matchtype;
                foreach my $bp (sort {$a <=> $b} keys %{$qid->{matchbp}}, $qbp) {
                    $qmatch .= $this->{ref}->{$qsid}->[$bp]->[0]->{id};
                    $qmatch .= $this->{ref}->{$qsid}->[$bp]->[0]->{fuzoku};
                    $qorigbp .= $this->{ref}->{$qsid}->[$bp]->[0]->{origbp} . " ";
                }
                foreach my $bp (sort {$a <=> $b} keys %{$tmid->{matchbp}}, $tmid->{node}) {
                    $tmatch .= $this->{ref}->{$tsid}->[$bp]->[0]->{id};
                    $tmatch .= $this->{ref}->{$tsid}->[$bp]->[0]->{fuzoku};
                    $torigbp .= $this->{ref}->{$tsid}->[$bp]->[0]->{origbp} . " ";
                }
		if ($qid->{relation} or $tmid->{relation}) {$matchtype = "上位下位マッチング";}
		elsif ($qid->{antonym} or $tmid->{antonym}) {$matchtype = "反義語マッチング";}
		else {$matchtype = "同義語マッチング"};
                $tm_result->{$tmid}->{matchbp}->{$qmatch}->{match_node} = $tmatch;
		$tm_result->{$tmid}->{matchbp}->{$qmatch}->{match_type} = $matchtype;
                $tm_result->{$tmid}->{origbp}->{$qorigbp}->{match_bp}   = $torigbp;
                $tm_result->{$tmid}->{origbp}->{$qorigbp}->{match_type} = $matchtype;

                # 兄弟はマッチさせない
                my $m_score;
                unless ($qid->{relation} and $tmid->{relation}) {
		    # スコア計算
		    # 解消されることのないペナルティは{match}{unmatch}どちらにもかける。解消される可能性のあるものは{unmatch}のみにかける。
		    $tm_result->{$tmid}->{match_weight}->{match} =
			$qid->{score} * $qid->{weight} * $tmid->{score};
		    $tm_result->{$tmid}->{match_weight}->{unmatch} =
			$qid->{score} * $qid->{weight} * $tmid->{score};
		    
		    # IREX用 （要改定）
		    if ($this->{mode} =~ /irex/) {
			my $key = $tmid->{id};
			my $docid = (split(/,/, $tsid))[0];
			my $weight =
			    3.0 /
			    ((0.5+1.5*$this->{doclen}->{$docid}/$this->{doclen}->{avg_doclen}) + $this->{tf}->{$docid}->{$key}) *
			    log(($this->{doclen}->{num_doc}-$this->{df}->{$key}+0.5) / ($this->{df}->{$key}+0.5));
			$weight = 0 if ($weight < 0);
			
			$tm_result->{$tmid}->{match_weight}->{match}   *= $weight if ($key);
			$tm_result->{$tmid}->{match_weight}->{unmatch} *= $weight if ($key);
			
			# マッチしたIDのスコア
			$m_score = $tm_result->{$tmid}->{match_weight}->{match};
			# stfをかける
			$tm_result->{$tmid}->{match_weight}->{match}   *= @{$this->{thash}->{$tsid}->{$qid->{id}}} if ($qid->{id});
			$tm_result->{$tmid}->{match_weight}->{unmatch} *= @{$this->{thash}->{$tsid}->{$qid->{id}}} if ($qid->{id});
		    }
		    else {
			# マッチしたIDのスコア
			$m_score = $tm_result->{$tmid}->{match_weight}->{match};
		    }

 		    # 格の不一致によるペナルティ
		    if ($qid->{case} && $tmid->{case}) {
			if ($qid->{case} ne $tmid->{case}) {
			    $tm_result->{$tmid}->{match_weight}->{unmatch} *= $SynGraph::case_penalty;
			    $tm_result->{$tmid}->{case_unmatch} = 1;
			}
		    }
		    # 可能表現のフラグ不一致によるペナルティ（解消されることがない）
		    if ($qid->{kanou} ne $tmid->{kanou}) {
			$tm_result->{$tmid}->{match_weight}->{match}   *= $SynGraph::kanou_penalty;
			$tm_result->{$tmid}->{match_weight}->{unmatch} *= $SynGraph::kanou_penalty;
		    }

		    # 尊敬表現のフラグ不一致によるペナルティ（解消されることがない）
		    if ($qid->{sonnkei} ne $tmid->{sonnkei}) {
			$tm_result->{$tmid}->{match_weight}->{match}   *= $SynGraph::sonnkei_penalty;
			$tm_result->{$tmid}->{match_weight}->{unmatch} *= $SynGraph::sonnkei_penalty;
		    }

		    # 受身表現のフラグ不一致によるペナルティ
		    if ($qid->{ukemi} ne $tmid->{ukemi}) {
			$tm_result->{$tmid}->{match_weight}->{unmatch} *= $SynGraph::ukemi_penalty;
			$tm_result->{$tmid}->{ukemi_unmatch} = 1;
		    }

		    # 否定、反義語のフラグ不一致によるペナルティ
		    if ($qid->{negation} ^ $tmid->{negation} ^ $qid->{antonym} ^ $tmid->{antonym}) {
			$tm_result->{$tmid}->{match_weight}->{unmatch} *= $SynGraph::negation_penalty;
			$tm_result->{$tmid}->{node_reversal} = 1;
			$tm_result->{$tmid}->{sentence_reversal} ^= 1;
		    }
		    
#		    # 付属語
#                     if ($qid->{fuzoku} ne $tmid->{fuzoku}) {
#                         $tm_result->{$tmid}->{match_weight} *= $SynGraph::fuzoku_penalty;
#                     }
		    
		    # マッチしたノードtmidがqidの親のマッチしたtmidの子供であるかチェック
		    if (ref($c_ref) eq 'HASH' and $qid->{weight} != 0 and $k_score != -1) {
			foreach my $tcbp (keys %$c_ref) {
			    if (grep($tmid eq $_, @{$this->{ref}->{$tsid}->[$tcbp]})) {
				#解消される可能性のあるペナルティが解消されたら{match}。されなかったら{unmatch}。
				if ($this->{mode} =~ /irex/) {
				    $tm_result->{$tmid}->{match_kakari}->{match}   = $m_score + $k_score;    #$k_scoreは一つ親の$m_score
				    $tm_result->{$tmid}->{match_kakari}->{unmatch} = 0;
				}
				else {
				    $tm_result->{$tmid}->{match_kakari}->{match}   = 1;
				    $tm_result->{$tmid}->{match_kakari}->{unmatch} = 0;
				}
				last;
			    }
			}
		    }
		}
                # 子供がいる
                if ($qid->{childbp}) {
                    foreach my $cbp (keys %{$qid->{childbp}}) {
			my $r = $this->matching($qsid,
						$cbp,
						$tsid,
						$tmid->{childbp},
						$qid->{weight} != 0 ? $m_score : -1);
			$tm_result->{$tmid}->{weight}                       += $r->{weight};
			$tm_result->{$tmid}->{kakari}                       += $r->{kakari};
			$tm_result->{$tmid}->{case_unmatch}                 += $r->{case_unmatch};
			# 子供が用言で、レベルがB+未満のときはsentence_reversalを引き継ぐ
			if ($this->{ref}->{$qsid}->[$cbp]->[0]->{level} !~ /(B\+|C)/) {
			    $tm_result->{$tmid}->{sentence_reversal}                  ^= $r->{sentence_reversal};
			    $tm_result->{$tmid}->{match_weight}->{match}              += $r->{match_weight}->{match};
			    $tm_result->{$tmid}->{match_weight}->{unmatch}            += $r->{match_weight}->{unmatch};
			    $tm_result->{$tmid}->{match_kakari}->{match}              += $r->{match_kakari}->{match};
			    $tm_result->{$tmid}->{match_kakari}->{unmatch}            += $r->{match_kakari}->{unmatch};
			}
			# 子供が用言で、レベルがB+以上のときはsentence_reversalを引き継がない
			else { 
			    my $match_or_unmatch = $r->{sentence_reversal} = 0 ? 'match' : 'unmatch'; 
			    $tm_result->{$tmid}->{match_weight}->{match}              += $r->{match_weight}->{$match_or_unmatch};
			    $tm_result->{$tmid}->{match_weight}->{unmatch}            += $r->{match_weight}->{$match_or_unmatch};
			    $tm_result->{$tmid}->{match_kakari}->{match}              += $r->{match_kakari}->{$match_or_unmatch};
			    $tm_result->{$tmid}->{match_kakari}->{unmatch}            += $r->{match_kakari}->{$match_or_unmatch};
			}
			while (my ($key, $value) = each %{$r->{matchbp}}) {
			    $tm_result->{$tmid}->{matchbp}->{$key} = $value;
			}
			while (my ($key, $value) = each %{$r->{origbp}}) {
			    $tm_result->{$tmid}->{origbp}->{$key} = $value;
			}		    
		    }

		    # 比較表現の主語と比較対象の反転をチェック
		    # 子供の格の不一致が２つ以上あったときは自身のnode_reversal解消、sentence_reversalの値も変更する
		    if ($tm_result->{$tmid}->{case_unmatch} == 2 && $tm_result->{$tmid}->{node_reversal}){
			$tm_result->{$tmid}->{case_unmatch}  = 0;
			$tm_result->{$tmid}->{node_reversal} = 0;
			$tm_result->{$tmid}->{sentence_reversal} ^= 1;
		    }
		    
		    # 受身表現による違いの吸収
		    # 子供の格の不一致が２つ以上あったときは自身のukemi_unmatch解消
		    if ($tm_result->{$tmid}->{case_unmatch} == 2 && $tm_result->{$tmid}->{ukemi_unmatch}){
			$tm_result->{$tmid}->{case_unmatch} = 0;
			$tm_result->{$tmid}->{ukemi_unmatch} = 0;
		    }
                }
                # スコア計算
                if ($this->{mode} =~ /irex/) {
		    if ($tm_result->{$tmid}->{sentence_reversal} == 0
			&& $tm_result->{$tmid}->{case_unmatch} == 0
			&& $tm_result->{$tmid}->{ukemi_unmatch} == 0){
			$tm_result->{$tmid}->{score} =
			    $tm_result->{$tmid}->{match_weight}->{match} + $tm_result->{$tmid}->{match_kakari}->{match} * 0.5;
		    }
		    else {
			$tm_result->{$tmid}->{score} =
			    $tm_result->{$tmid}->{match_weight}->{unmatch} + $tm_result->{$tmid}->{match_kakari}->{unmatch} * 0.5;
		    }
		}
                else {
		    if ($tm_result->{$tmid}->{sentence_reversal} == 0
			&& $tm_result->{$tmid}->{case_unmatch} == 0
			&& $tm_result->{$tmid}->{ukemi_unmatch} == 0){
			$tm_result->{$tmid}->{score} =
			    ($tm_result->{$tmid}->{match_weight}->{match} + $kakari_weight * $tm_result->{$tmid}->{match_kakari}->{match})
			    / ($tm_result->{$tmid}->{weight} + $kakari_weight * $tm_result->{$tmid}->{kakari});
		    }      
		    else {
			$tm_result->{$tmid}->{score} =
			    ($tm_result->{$tmid}->{match_weight}->{unmatch} + $kakari_weight * $tm_result->{$tmid}->{match_kakari}->{unmatch})
			    / ($tm_result->{$tmid}->{weight} + $kakari_weight * $tm_result->{$tmid}->{kakari});
		    }
		}
            }
            # 一番良いもの（同じidの$tmidのうちでマッチしたときにもっともスコアの高いもの）
#            foreach my $tmid (sort {$tm_result->{$b}->{score} <=> $tm_result->{$a}->{score}} keys %$tm_result) {
            foreach my $tmid (sort {$tm_result->{$b}->{match_weight} <=> $tm_result->{$a}->{match_weight}} keys %$tm_result) {
                $result->{$qid} = $tm_result->{$tmid};
                last;
            }
	}
        # マッチしない
        else {
            # 子供がいる
            if ($qid->{childbp}) {
                foreach my $cbp (keys %{$qid->{childbp}}) {
		    my $r = $this->matching($qsid, $cbp, $tsid, 0, 0);
		    $result->{$qid}->{weight}                    += $r->{weight};
		    $result->{$qid}->{kakari}                    += $r->{kakari};
		    $result->{$qid}->{case_unmatch}               = $r->{case_unmatch};
		    # 子供が動詞で、レベルがB+未満のときはsentence_reversalを引き継ぐ                     
		    if ($this->{ref}->{$qsid}->[$cbp]->[0]->{level} !~ /(B\+|C)/) {
			$result->{$qid}->{sentence_reversal}         ^= $r->{sentence_reversal};
			$result->{$qid}->{match_weight}->{match}           += $r->{match_weight}->{match};
			$result->{$qid}->{match_weight}->{unmatch}         += $r->{match_weight}->{unmatch};
			$result->{$qid}->{match_kakari}->{match}           += $r->{match_kakari}->{match};
			$result->{$qid}->{match_kakari}->{unmatch}         += $r->{match_kakari}->{unmatch};
		    }
		    # 子供が動詞で、レベルがB+以上のときはsentence_reversalを引き継がない          
		    else { 
			my $match_or_unmatch = $r->{sentence_reversal} = 0 ? 'match' : 'unmatch'; 
			$result->{$qid}->{match_weight}->{match}           += $r->{match_weight}->{$match_or_unmatch};
			$result->{$qid}->{match_weight}->{unmatch}         += $r->{match_weight}->{$match_or_unmatch};
			$result->{$qid}->{match_kakari}->{match}           += $r->{match_kakari}->{$match_or_unmatch};
			$result->{$qid}->{match_kakari}->{unmatch}         += $r->{match_kakari}->{$match_or_unmatch};
		    }
		    while (my ($key, $value) = each %{$r->{origbp}}) {
			$result->{$qid}->{origbp}->{$key} = $value;
		    }
		}
	    }	                        
	    # スコア計算
	    if ($this->{mode} =~ /irex/) {
		if ($result->{$qid}->{sentence_reversal} == 0){
		    $result->{$qid}->{score} =
			$result->{$qid}->{match_weight}->{match} + $result->{$qid}->{match_kakari}->{match} * 0.5;
		}
		else {
		    $result->{$qid}->{score} =
			$result->{$qid}->{match_weight}->{unmatch} + $result->{$qid}->{match_kakari}->{unmatch} * 0.5;		    
		}
            }
            else {
		if ($result->{$qid}->{sentence_reversal} == 0){		
		    $result->{$qid}->{score} =
			($result->{$qid}->{match_weight}->{match} + $kakari_weight * $result->{$qid}->{match_kakari}->{match})
			/ ($result->{$qid}->{weight} + $kakari_weight * $result->{$qid}->{kakari});
		}
		else{
		    $result->{$qid}->{score} =
			($result->{$qid}->{match_weight}->{unmatch} + $kakari_weight * $result->{$qid}->{match_kakari}->{unmatch})
			/ ($result->{$qid}->{weight} + $kakari_weight * $result->{$qid}->{kakari});
		}

	    }
        }
    }
    # 一番良いものを返す（同じタグの中のqidのうちで）
#    foreach my $node (sort {$result->{$b}->{score} <=> $result->{$a}->{score}} keys %$result) {
    foreach my $node (sort {$result->{$b}->{match_weight}->{match} <=> $result->{$a}->{match_weight}->{match}} keys %$result) {
        $this->{matching_tmp}->{$qbp}->{$c_ref} = $result->{$node};
        return $result->{$node};
    }
}


#
# インデックスをtie
#
sub tie_index {
    my ($this, @index_files) = @_;
    
    foreach my $index_file (@index_files) {
        my %index;
        &SynGraph::tie_db($index_file, \%index);
        push(@{$this->{index}}, \%index);
    }
}


#
# インデックスをuntie
#
sub untie_index {
    my ($this) = @_;

    foreach my $index (@{$this->{index}}) {
        untie %$index;
    }
}


1;
