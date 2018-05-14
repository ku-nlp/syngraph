# $Id: Obsolete.pm,v 1.2 2006/10/31 08:53:08 shibata Exp $
package KNP::Obsolete;
require 5.003_09; # For UNIVERSAL->can().
use Carp;
use English qw/ $LIST_SEPARATOR /;
use strict;

=head1 NAME

KNP::Obsolete - �����ߴ��Υ᥽�åɤ��������

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KNP::Obsolete> ���饹�ϡ�C<KNP> �⥸�塼��˰���(2001ǯ8��28����)��
Ʊ�� API ���ɲä��륯�饹�Ǥ��롥

=head1 CONSTRUCTOR

���Υ��饹�ϥߥ����󥰤��ƻ��Ѥ���褦���߷פ���Ƥ��뤿�ᡤ���̤ʥ���
���ȥ饯�����������Ƥ��ʤ���

=head1 METHODS

=over 4

=item all()

KNP �����Ϥ�����ʸ���Ϸ�̤��Τޤޤ�ʸ������֤��᥽�åɡ�

=cut
sub all {
    shift->{ALL};
}

=item comment()

KNP �����Ϥ�����ʸ���Ϸ�̤���Ƭ�˴ޤޤ�륳���Ȥ��֤��᥽�åɡ�

=cut
sub comment {
    shift->{COMMENT};
}

=item mrph_num()

�����ǿ����֤��᥽�åɡ�

=cut
sub mrph_num {
    scalar( @{shift->{MRPH}} );
}

=item mrph( [ARG,TYPE,SUFFIX] )

��ʸ���Ϸ�̤η����Ǿ���˥����������뤿��Υ᥽�åɡ�

Examples:

   $knp->mrph;
   # ��������ά���줿���ϡ������Ǿ���Υꥹ�Ȥ���
   # �����ե���󥹤��֤���

   $knp->mrph( 1 );
   # ARG �ˤ�äơ������ܤη����Ǥξ�����֤������
   # �ꤹ�롣���ξ��ϡ�1���ܤη����Ǿ���Υϥå���
   # ���Ф����ե���󥹤��֤���

   $knp->mrph( 2, 'fstring' );
   # TYPE �ˤ�ä�ɬ�פʷ����Ǿ������ꤹ�롣���ξ�
   # �硢2���ܤη����Ǥ����Ƥ� feature ��ʸ�������
   # ����

   $knp->mrph( 3, 'feature', 4 );
   # 3���ܤη����Ǥ�4���ܤ� feature ���֤���

TYPE �Ȥ��ƻ��ꤹ�뤳�Ȥ��Ǥ���ʸ����ϼ����̤�Ǥ��롣

   midasi
   yomi
   genkei
   hinsi
   hinsi_id
   bunrui
   bunrui_id
   katuyou1
   katuyou1_id
   katuyou2
   katuyou2_id
   imis
   fstring
   feature

��3���� SUFFIX ���뤳�Ȥ��Ǥ���Τ� TYPE �Ȥ��� feature ����ꤷ����
��˸¤��롣

=cut
sub mrph {
    my $this = shift;
    unless( @_ ){
	$this->{MRPH};
    }
    else {
	my $i = shift;
	unless( my $mrph = $this->{MRPH}->[$i] ){
	    carp "Suffix ($i) is out of range";
	    undef;
	}
	else {
	    unless( @_ ){
		$mrph;
	    }
	    else {
		my $type = shift;
		if( @_ == 1 and $type eq "feature" ){
		    ( $mrph->feature )[ shift ];
		}
		elsif( @_ ){
		    local $LIST_SEPARATOR = ", ";
		    carp "Too many arguments ($i, $type, @_)";
		    undef;
		}
		elsif( $mrph->can($type) ){
		    $mrph->$type();
		}
		else {
		    carp "Unknown type ($type)";
		    undef;
		}
	    }
	}
    }
}

=item bnst_num()

ʸ������֤��᥽�åɡ�

=cut
sub bnst_num {
    scalar( @{shift->{BNST}} );
}

=item bnst( [ARG,TYPE,SUFFIX] )

��ʸ���Ϸ�̤�ʸ��˴ؤ���������Ф��᥽�åɡ�

Examples:

   $knp->bnst;
   # ��������ά���줿���ϡ�ʸ�����Υꥹ�Ȥ��Ф�
   # ���ե���󥹤��֤���

   $knp->bnst( 1 );
   # ARG �ˤ�äơ������ܤ�ʸ��ξ�����֤��������
   # ���롣���ξ��ϡ�1���ܤ�ʸ�����Υϥå������
   # �����ե���󥹤��֤���

   $knp->bnst( 2, 'fstring' );
   # TYPE �ˤ�ä�ɬ�פ�ʸ��������ꤹ�롣���ξ�硢
   # 2���ܤ�ʸ������Ƥ� feature ��ʸ������֤���

   $knp->bnst( 3, 'feature', 4 );
   # 3���ܤ�ʸ���4���ܤ� feature ���֤���

TYPE �Ȥ��ƻ��ꤹ�뤳�Ȥ��Ǥ���ʸ����ϼ����̤�Ǥ��롣

   start
   end
   parent
   parent_id
   dpndtype
   child
   child_id
   fstring
   feature

��3���� SUFFIX ���뤳�Ȥ��Ǥ���Τ� TYPE �Ȥ��� feature ����ꤷ����
��˸¤��롣

=cut
sub bnst {
    my $this = shift;
    unless( @_ ){
	$this->{BNST};
    } else {
	my $i = shift;
	unless( my $bnst = $this->{BNST}->[$i] ){
	    carp "Suffix ($i) is out of range";
	    undef;
	}
	else {
	    unless( @_ ){
		$bnst;
	    }
	    else {
		my $type = shift;
		if( @_ == 1 and $type eq "feature" ){
		    ( $bnst->feature )[ shift ];
		}
		elsif( @_ ){
		    local $LIST_SEPARATOR = ", ";
		    carp "Too many arguments ($i, $type, @_)";
		    undef;
		}
		elsif( $bnst->can($type) ){
		    $bnst->$type();
		}
		elsif ( $type eq 'start' ) {
		    ( $bnst->mrph )[0]->id;
		}
		elsif ( $type eq 'end' ) {
		    ( $bnst->mrph )[-1]->id;
		}
		elsif ( $type eq 'parent_id' ) {
		    if ( my $parent = $bnst->parent ) {
			$parent->id;
		    } else {
			-1;
		    }
		}
		elsif ( $type eq 'child_id' ) {
		    map( $_->id, $bnst->child );
		}
		else {
		    carp "Unknown method ($type)";
		    undef;
		}
	    }
	}
    }
}

sub draw_tree {
    my $blist = KNP::BList->new( @{shift->{BNST}} );
    $blist->set_nodestroy();
    $blist->draw_tree( @_ );
}

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP>

=back

=head1 AUTHOR

=over 4

=item
�ڲ� ��̭ <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=cut

1;
__END__
# Local Variables:
# mode: perl
# coding: euc-japan
# use-kuten-for-period: nil
# use-touten-for-comma: nil
# End:
