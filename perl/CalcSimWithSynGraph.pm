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
    my $match_option;
    $knp_option->{case} = 1 if $option->{case};
    $knp_option->{postprocess} = 1 if $option->{postprocess};
    $regnode_option->{relation} = 1 if $option->{relation};
    $regnode_option->{antonym} = 1 if $option->{antonym};
    $match_option->{jyutugokou_kaisyou} = 1 if $option->{jyutugokou_kaisyou};
    $matching_option->{MT_ver} = 1 if $option->{MT_ver};    

    my $search = new Search(undef, undef, $knp_option);

    my $sid1 = "$id-1";
    my $sid2 = "$id-2";
    
    # SYNGRAPHを作成

    $search->{sgh}->make_sg($str1, $search->{ref}, $sid1, $regnode_option, $match_option);
    $search->{sgh}->make_sg($str2, $search->{ref}, $sid2, $regnode_option, $match_option);
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
	my $result = $search->{sgh}->pmatch($graph_1, $headbp_1, $graph_2, $headbp_2);
	return 'unmatch' if ($result eq 'unmatch');
	if ($match_option->{jyutugokou_kaisyou}){
	    my $kaisyou = $search->{sgh}->jyutugokou_check($result->{NODE}, $headbp_2);
	    foreach my $bp (keys %{$kaisyou}) {
		$result->{NODE}->{$bp}->{kaisyou} = $kaisyou->{$bp};
	    }
	}

	# 類似度計算
	my $calc = $search->{sgh}->calc_sim('Matching', $result->{NODE}, $headbp_2, $headbp_2);
	return 'unmatch' if ($calc eq 'unmatch');
	$result->{CALC} = $calc;
	if ($option->{debug}) {
	    print "calc_sim結果\n";
	    Dumpvalue->new->dumpValue($result);
	} 

	# マッチペア出力
	if ($option->{debug}) {
	    print "matchpair\n";
	    for (my $num=0; $num<@{$result->{MATCH}->{match}}; $num++) {
		print "$num\n";
		printf "graph_1: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{graph_1}, join(',', @{$result->{MATCH}->{match}->[$num]->{graph_1}}), $result->{MATCH}->{matchid}->[$num]->{graph_1};
		printf "graph_2: %s (bp = %s, id = %s)\n", $result->{MATCH}->{matchpair}->[$num]->{graph_2}, join(',', @{$result->{MATCH}->{match}->[$num]->{graph_2}}), $result->{MATCH}->{matchid}->[$num]->{graph_2};
	    }
	}
	
	return $result;
    }
}
1;
