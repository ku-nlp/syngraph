# $Id: BList.pm,v 1.2 2006/10/31 08:53:08 shibata Exp $
package KNP::BList;
require 5.004_04; # For base pragma.
use KNP::Bunsetsu;
use KNP::TList;
use strict;
use base qw/ KNP::DrawTree KNP::KULM::BList KNP::KULM::TList Juman::KULM::MList /;

=head1 NAME

KNP::BList - ʸ���󥪥֥�������

=head1 SYNOPSIS

  $result = new KNP::BList();

=head1 DESCRIPTION

ʸ������ݻ����륪�֥������ȡ�

=head1 CONSTRUCTOR

=over 4

=item new( @BNST )

���ꤵ�줿ʸ��Υꥹ�Ȥ��ݻ����륪�֥������Ȥ��������롥��������ά����
�����ϡ���ʸ������ݻ����륪�֥������Ȥ��������롥

=cut
sub new {
    my $new = bless( {}, shift );
    if( @_ ){
	$new->push_bnst( @_ );
    }
    $new;
}

=back

=head1 METHODS

=over 4

=item bnst ( NUM )

�� I<NUM> ���ܤ�ʸ����֤���

=item bnst

���Ƥ�ʸ��Υꥹ�Ȥ��֤���

=begin comment

C<bnst> �᥽�åɤμ��Τϡ�C<KNP::KULM::BList> ���饹���������Ƥ��롥

=end comment

=item bnst_list

���Ƥ�ʸ��Υꥹ�Ȥ��֤���

=cut
sub bnst_list {
    my( $this ) = @_;
    if( defined $this->{bnst} ){
	@{$this->{bnst}};
    } else {
	wantarray ? () : 0;
    }
}

=item push_bnst( @BNST )

���ꤵ�줿ʸ�����ʸ�����ɲä��롥

=cut
sub push_bnst {
    my( $this, @bnst ) = @_;
    if( grep( ! $_->isa('KNP::Bunsetsu'), @bnst ) ){
	die "Illegal type of argument.";
    } elsif( $this->{BLIST_READONLY} ){
	die;
    } else {
	push( @{ $this->{bnst} ||= [] }, @bnst );
    }
}

=item tag ( NUM )

�� I<NUM> ���ܤΥ������֤���

=item tag

���ƤΥ����Υꥹ�Ȥ��֤���

=begin comment

C<tag> �᥽�åɤμ��Τϡ�C<KNP::KULM::TList> ���饹���������Ƥ��롥

=end comment

=item tag_list

���ƤΥ����Υꥹ�Ȥ��֤���

=cut
sub tag_list {
    map( $_->tag_list, shift->bnst_list );
}

=item push_tag( @TAG )

���ꤵ�줿������ʸ�����ɲä�������ʸ��Υ�����Ȥ��Ƥ�Ĺ�����֤����ɲ�
�оݤȤʤ�ʸ�᤬¸�ߤ��ʤ�(= ʸ���󤬶��Ǥ���)���ϡ��ɲäϹԤ��ʤ���

=cut
sub push_tag {
    my $this = shift;
    if( $this->bnst_list ){
	( $this->bnst_list )[-1]->push_tag( @_ );
    } else {
	0;
    }
}

=item mrph ( NUM )

�� I<NUM> ���ܤη����Ǥ��֤���

=item mrph

���Ƥη����ǤΥꥹ�Ȥ��֤���

=begin comment

C<mrph> �᥽�åɤμ��Τ� C<Juman::KULM::MList> ���������Ƥ��롥

=end comment

=item mrph_list

���Ƥη����ǤΥꥹ�Ȥ��֤���

=cut
sub mrph_list {
    map( $_->mrph_list, shift->bnst_list );
}

=item push_mrph( @MRPH )

���ꤵ�줿�����Ǥ�ʸ�����ɲä�������ʸ��η�������Ȥ��Ƥ�Ĺ�����֤���
�ɲ��оݤȤʤ�ʸ�᤬¸�ߤ��ʤ�(= ʸ���󤬶��Ǥ���)���ϡ��ɲäϹԤ��
�ʤ���

=cut
sub push_mrph {
    my $this = shift;
    if( $this->bnst_list ){
	( $this->bnst_list )[-1]->push_mrph( @_ );
    } else {
	0;
    }
}

=item set_readonly

ʸ������Ф���񤭹��ߤ��Ե��Ĥ����ꤹ�롥

=cut
sub set_readonly {
    my( $this ) = @_;
    for my $bnst ( $this->bnst_list ){
	$bnst->set_readonly();
    }
    $this->{BLIST_READONLY} = 1;
}

=item spec

ʸ�����ʸ������Ѵ����롥

=cut
sub spec {
    my( $this ) = @_;
    join( '', map( $_->spec, $this->bnst_list ) );
}

=item draw_tree

=item draw_bnst_tree

ʸ����ΰ�¸�ط����ڹ�¤�Ȥ���ɽ�����ƽ��Ϥ��롥

=cut
sub draw_bnst_tree {
    shift->draw_tree( @_ );
}

=item draw_tag_tree

������ΰ�¸�ط����ڹ�¤�Ȥ���ɽ�����ƽ��Ϥ��롥

=cut
sub draw_tag_tree {
    my $tlist = KNP::TList->new( shift->tag_list );
    $tlist->set_nodestroy();
    $tlist->draw_tree( @_ );
}

# draw_tree �᥽�åɤȤ��̿��ѤΥ᥽�åɡ�
sub draw_tree_leaves {
    shift->bnst_list( @_ );
}

sub set_nodestroy {
    shift->{BLIST_NODESTROY} = 1;
}

=back

=head1 DESTRUCTOR

ʸ�ᥪ�֥������ȴ֤˴ľ��Υ�ե���󥹤����������ȡ��̾�� Garbage
Collection �ˤ�äƤϥ��꤬�������ʤ��ʤ롥����������򤱤뤿��ˡ�
����Ū�˥�ե���󥹤��˲����� destructor ��������Ƥ��롥

=cut
sub DESTROY {
    my( $this ) = @_;
    unless( $this->{BLIST_NODESTROY} ){
	grep( ref $_ && $_->isa('KNP::Bunsetsu') && $_->DESTROY, $this->bnst_list );
    }
}

=head1 SEE ALSO

=over 4

=item *

L<KNP::Bunsetsu>

=back

=head1 AUTHOR

=over 4

=item
�ڲ� ��̭ <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=back

=cut

1;
__END__
# Local Variables:
# mode: perl
# coding: euc-japan
# use-kuten-for-period: nil
# use-touten-for-comma: nil
# End:
