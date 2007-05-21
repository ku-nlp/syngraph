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
    my ($this) = @_;

    $this = {};

    bless $this;

    return $this;
}

# 類似度計算
sub Match {
    my ($this, $id, $str1, $str2, $option) = @_;

    my $syndbdir = !$option->{orchid} ?  '../syndb/i686' : '../syndb/x86_64';
    my $knp_option; 
    my $regnode_option;
    my $matching_option;
    my $matching_option;
    $knp_option->{no_case} = 1 if $option->{no_case};
    $knp_option->{postprocess} = 1 if $option->{postprocess};
    $regnode_option->{relation} = 1 if $option->{relation};
    $regnode_option->{antonym} = 1 if $option->{antonym};
    $matching_option->{pa_matching} = 1 if $option->{pa_matching};
    $matching_option->{wr_matching} = 1 if $option->{wr_matching};
    $option->{log_sg} = 1 if $option->{log_sg};

    my $SynGraph = new SynGraph($syndbdir, $knp_option);    

    my $sid1 = "$id-1";
    my $sid2 = "$id-2";
    
    # SYNGRAPHを作成
    my $ref={};
    $SynGraph->make_sg($str1, $ref, $sid1, $regnode_option, $option);
    $SynGraph->make_sg($str2, $ref, $sid2, $regnode_option, $option);
    Dumpvalue->new->dumpValue($ref) if $option->{debug};
#    $search->{sgh}->format_syngraph($search->{ref}->{$sid1}) if $option->{debug};
#    $search->{sgh}->format_syngraph($search->{ref}->{$sid2}) if $option->{debug};

    my $graph_1 = $ref->{$sid1};
    my $headbp_1 = @{$ref->{$sid1}}-1;
    my $graph_2 = $ref->{$sid2};   
    my $headbp_2 = @{$ref->{$sid2}}-1;
    
    # SYNGRAPHのマッチング
    # garaph_1は部分、graph_2は完全マッチング
    my $result = $SynGraph->syngraph_matching('Matching', $graph_1, $headbp_1, $graph_2, $headbp_2, undef, $matching_option);
    
    if ($option->{debug} and $result ne 'unmatch') {
	print "SYNGRAPHマッチング結果\n";
	Dumpvalue->new->dumpValue($result);
    }
    
    # マッチペア出力
    if ($option->{debug} and $result ne 'unmatch') {
	print "matchpair\n";
	for (my $num=0; $num<@{$result->{MATCH}->{match}}; $num++) {
		print "$num\n";
		printf "graph_1: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{graph_1}, join(',', @{$result->{MATCH}->{match}->[$num]->{graph_1}}), $result->{MATCH}->{matchid}->[$num]->{graph_1};
		printf "graph_2: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{graph_2}, join(',', @{$result->{MATCH}->{match}->[$num]->{graph_2}}), $result->{MATCH}->{matchid}->[$num]->{graph_2};
	    }
    }
    
    return $result;
}


# 	# 転置ハッシュを作る
# 	$search->{thash} = {};
# 	foreach my $sid (keys %{$search->{ref}}) {
# 	    for (my $tagnum = 0; $tagnum < @{$search->{ref}->{$sid}}; $tagnum++) {
# 		my $tag = $search->{ref}->{$sid}->[$tagnum];
# 		foreach my $id (@$tag) {
# #		    $id->{tag} = $tagnum;       # 対応付けのために必要
# 		    $id->{node} = $tagnum;       # 対応付けのために必要
# #		    push(@{$search->{thash}->{$sid}->{$id->{idname}}}, $id);
# 		    push(@{$search->{thash}->{$sid}->{$id->{id}}}, $id);
# 		}
# 	    }
# 	}
#	print STDERR "thash\n";
#	Dumpvalue->new->dumpValue($search->{thash});

# 	# 類似度計算
# 	$search->{matching_tmp} = {};
# 	my $result = $search->matching($sid2, @{$search->{ref}->{$sid2}}-1, $sid1, 0, -1);
# 	Dumpvalue->new->dumpValue($result) if $option->{debug};
	
# 	return $result;
#     }


1;
