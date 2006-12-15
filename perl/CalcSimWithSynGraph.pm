package CalcSimWithSynGraph;

# $Id$

use utf8;
use strict;
use Encode;
use lib qw(../perl);
use SynGraph;
use Search;

#
# ���󥹥ȥ饯��
#
sub new {
    my ($this) = @_;

    $this = {};

    bless $this;

    return $this;
}

# ����ٷ׻�
sub Match {
    my ($this, $id, $str1, $str2, $option) = @_;

    my $knp_option; 
    my $regnode_option;
    $knp_option->{case} = 1 if $option->{case};
    $knp_option->{postprocess} = 1 if $option->{postprocess};
    $regnode_option->{relation} = 1 if $option->{relation};
    $regnode_option->{antonym} = 1 if $option->{antonym};

    my $search = new Search(undef, undef, $knp_option);

    my $sid1 = "$id-1";
    my $sid2 = "$id-2";

    # SYNGRAPH�����

    $search->{sgh}->make_sg($str1, $search->{ref}, $sid1, $regnode_option);
    $search->{sgh}->make_sg($str2, $search->{ref}, $sid2, $regnode_option);
    Dumpvalue->new->dumpValue($search->{ref}) if $option->{debug};

    # ž�֥ϥå������
    $search->{thash} = {};
    foreach my $sid (keys %{$search->{ref}}) {
	for (my $tagnum = 0; $tagnum < @{$search->{ref}->{$sid}}; $tagnum++) {
	    my $tag = $search->{ref}->{$sid}->[$tagnum];
	    foreach my $id (@$tag) {
#		$id->{tag} = $tagnum;       # �б��դ��Τ����ɬ��
		$id->{node} = $tagnum;       # �б��դ��Τ����ɬ��
#		push(@{$search->{thash}->{$sid}->{$id->{idname}}}, $id);
		push(@{$search->{thash}->{$sid}->{$id->{id}}}, $id);
	    }
	}
    }
#    print STDERR "thash\n";
#    Dumpvalue->new->dumpValue($search->{thash});

    # ����ٷ׻�
    $search->{matching_tmp} = {};
    my $result = $search->matching($sid2, @{$search->{ref}->{$sid2}}-1, $sid1, 0, -1);
    Dumpvalue->new->dumpValue($result) if $option->{debug};
    
    return $result;
}

1;
