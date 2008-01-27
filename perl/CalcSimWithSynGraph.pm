package CalcSimWithSynGraph;

# $Id$

use utf8;
use strict;
use Encode;
use lib qw(../perl);
use SynGraph;

#
# コンストラクタ
#
sub new {
    my ($this, $option) = @_;

    # DBの場所指定
    my $syndbdir;
    if ($option->{syndbdir}) {
	$syndbdir = $option->{syndbdir} . (!$option->{orchid} ?  'i686' : 'x86_64');
    }
    else {
	$syndbdir = !$option->{orchid} ?  '../syndb/i686' : '../syndb/x86_64';
    }
    
    # 各種option
    my $knp_option; 
    $knp_option->{no_case} = 1 if $option->{no_case};
    $knp_option->{postprocess} = 1 if $option->{postprocess};

    $this = { sgh => new SynGraph($syndbdir, $knp_option)};

    bless $this;

    return $this;
}

# 類似度計算
sub Match {
    my ($this, $id, $str1, $str2, $option) = @_;

    # 各種option
    my $regnode_option;
    my $matching_option;
    $regnode_option->{relation} = 1 if $option->{relation};
    $regnode_option->{antonym} = 1 if $option->{antonym};
    $regnode_option->{hypocut_attachnode} = $option->{hypocut_attachnode} if $option->{hypocut_attachnode};
    $regnode_option->{relation_recursive} = $option->{relation_recursive} if $option->{relation_recursive};
    $matching_option->{coordinate_matching} = 1 if $option->{coordinate_matching};
    $matching_option->{hypocut_matching} = $option->{hypocut_matching} if $option->{hypocut_matching};

    my $sid1 = "$id-1";
    my $sid2 = "$id-2";
    
    # SYNGRAPHを作成
    my $ref={};
    $this->{sgh}->make_sg($str1, $ref, $sid1, $regnode_option, $option);
    $this->{sgh}->make_sg($str2, $ref, $sid2, $regnode_option, $option);
    Dumpvalue->new->dumpValue($ref) if $option->{debug};

    my $graph_1 = $ref->{$sid1};
    my $headbp_1 = @{$ref->{$sid1}}-1;
    my $graph_2 = $ref->{$sid2};   
    my $headbp_2 = @{$ref->{$sid2}}-1;
    
    # SYNGRAPHのマッチング
    # garaph_1は部分、graph_2は完全マッチング
    my ($result_rough, $match_verbose) = $this->{sgh}->syngraph_matching_rough($graph_1, $headbp_1, $graph_2, $headbp_2, undef, $matching_option);
    return if $result_rough == 0;
    my ($result, $newnode) = $this->{sgh}->syngraph_matching_and_get_newnode('MT', $graph_1, $headbp_1, $graph_2, $headbp_2, $match_verbose);
    return if $result == 0;

    if ($option->{debug}) {
	print "SYNGRAPHマッチング結果\n";
	Dumpvalue->new->dumpValue($newnode);
    }
    
    # マッチペア出力
    if ($option->{debug}) {
	print "matchpair\n";
	for (my $num = 0; $num < @{$newnode->{match}}; $num++) {
		print "$num\n";
		printf "graph_1: %s (bp = %s, id = %s)\n", $newnode->{matchpair}[$num]{graph_1}, join('/', @{$newnode->{match}[$num]{graph_1}}), $newnode->{matchid}[$num]{graph_1};
		printf "graph_2: %s (bp = %s, id = %s)\n", $newnode->{matchpair}[$num]{graph_2}, join('/', @{$newnode->{match}[$num]{graph_2}}), $newnode->{matchid}[$num]{graph_2};
	    }
    }
    
    return ($result, $newnode);
}


1;
