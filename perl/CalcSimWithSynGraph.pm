package CalcSimWithSynGraph;

# $Id$

use utf8;
use strict;
use Encode;
use lib qw(../perl);
use SynGraph;
use Search;

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

    my $knp_option; 
    my $regnode_option;
    my $matching_option;
    $knp_option->{case} = 1 if $option->{case};
    $knp_option->{postprocess} = 1 if $option->{postprocess};
    $regnode_option->{relation} = 1 if $option->{relation};
    $regnode_option->{antonym} = 1 if $option->{antonym};
    $matching_option->{MT_ver} = 1 if $option->{MT_ver};    

    my $search = new Search(undef, undef, $knp_option);

    my $sid1 = "$id-1";
    my $sid2 = "$id-2";

    # SYNGRAPHを作成

    $search->{sgh}->make_sg($str1, $search->{ref}, $sid1, $regnode_option);
    $search->{sgh}->make_sg($str2, $search->{ref}, $sid2, $regnode_option);
    Dumpvalue->new->dumpValue($search->{ref}) if $option->{debug};

    if (!$matching_option->{MT_ver}) {
	# 転置ハッシュを作る
	$search->{thash} = {};
	foreach my $sid (keys %{$search->{ref}}) {
	    for (my $tagnum = 0; $tagnum < @{$search->{ref}->{$sid}}; $tagnum++) {
		my $tag = $search->{ref}->{$sid}->[$tagnum];
		foreach my $id (@$tag) {
#		    $id->{tag} = $tagnum;       # 対応付けのために必要
		    $id->{node} = $tagnum;       # 対応付けのために必要
#		    push(@{$search->{thash}->{$sid}->{$id->{idname}}}, $id);
		    push(@{$search->{thash}->{$sid}->{$id->{id}}}, $id);
		}
	    }
	}
#	print STDERR "thash\n";
#	Dumpvalue->new->dumpValue($search->{thash});

	# 類似度計算
	$search->{matching_tmp} = {};
	my $result = $search->matching($sid2, @{$search->{ref}->{$sid2}}-1, $sid1, 0, -1);
	Dumpvalue->new->dumpValue($result) if $option->{debug};
	
	return $result;
    }

    else {
	my $graph_1 = $search->{ref}->{$sid1};
	my $headbp_1 = @{$search->{ref}->{$sid1}}-1;
	my $graph_2 = $search->{ref}->{$sid2};   
	my $headbp_2 = @{$search->{ref}->{$sid2}}-1;

	# garaph_1は部分、graph_2は完全マッチング
	my $pmatch_result = $search->{sgh}->pmatch($graph_1, $headbp_1, $graph_2, $headbp_2);
	return 'unmatch' if ($pmatch_result eq 'unmatch');
 	if $option->{debug}{
	    print "pmatch結果\n";
	    Dumpvalue->new->dumpValue($pmatch_result);
	}
	my $result = $search->{sgh}->calc_sim('Matching', $pmatch_result, $headbp_2, $headbp_2);
	if $option->{debug}{
	    print "calc_sim結果\n";
	    Dumpvalue->new->dumpValue($result);
	} 

	# マッチペア出力
	if ($option->{debug}) {
	    print "matchpair\n";
	    for (my $num=0; $num<@{$result->{MATCH}->{match}}; $num++) {
		print "$num\n";
		printf "graph_1: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{s}, join(',', @{$result->{MATCH}->{match}->[$num]->{s}}), $result->{MATCH}->{matchid}->[$num]->{s};
		printf "graph_2: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{i}, join(',', @{$result->{MATCH}->{match}->[$num]->{i}}), $result->{MATCH}->{matchid}->[$num]->{i};
	    }
	}
	
	return $result;
    }
}
1;
