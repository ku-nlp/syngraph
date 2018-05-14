# $Id: TList.pm,v 1.2 2006/10/31 08:53:08 shibata Exp $
package KNP::TList;
require 5.004_04; # For base pragma.
use KNP::Tag;
use strict;
use base qw/ KNP::DrawTree KNP::KULM::TList Juman::KULM::MList /;

=head1 NAME

KNP::TList - �����󥪥֥�������

=head1 SYNOPSIS

  $result = new KNP::TList();

=head1 DESCRIPTION

KNP �ˤ��ʲ��Ϥ�ñ�̤Ǥ��륿���Υꥹ�Ȥ��ݻ����륪�֥������ȡ�

=head1 CONSTRUCTOR

=over 4

=item new( @TAG )

���ꤵ�줿�����Υꥹ�Ȥ��ݻ����륪�֥������Ȥ��������롥��������ά����
�����ϡ����Υꥹ�Ȥ��ݻ����륪�֥������Ȥ��������롥

=cut
sub new {
    my $new = bless( {}, shift );
    if( @_ ){
	$new->push_tag( @_ );
    }
    $new;
}

=back

=head1 METHODS

=over 4

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
    my( $this ) = @_;
    if( defined $this->{tag} ){
	@{$this->{tag}};
    } else {
	wantarray ? () : 0;
    }
}

=item push_tag( @TAG )

���ꤵ�줿�����򥿥�����ɲä��롥

=cut
sub push_tag {
    my( $this, @tag ) = @_;
    if( grep( ! $_->isa('KNP::Tag'), @tag ) ){
	die "Illegal type of argument.";
    } elsif( $this->{TLIST_READONLY} ){
	die;
    } else {
	push( @{ $this->{tag} ||= [] }, @tag );
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
    map( $_->mrph_list, shift->tag_list );
}

=item push_mrph( @MRPH )

���ꤵ�줿�����Ǥ�ʸ�����ɲä������Υ����η�������Ȥ��Ƥ�Ĺ�����֤���
�ɲ��оݤȤʤ륿����¸�ߤ��ʤ�(= �����󤬶��Ǥ���)���ϡ��ɲäϹԤ��
�ʤ���

=cut
sub push_mrph {
    my( $this, @mrph ) = @_;
    if( $this->tag_list ){
	( $this->tag_list )[-1]->push_mrph( @mrph );
    } else {
	0;
    }
}

=item set_readonly

��������Ф���񤭹��ߤ��Ե��Ĥ����ꤹ�롥

=cut
sub set_readonly {
    my( $this ) = @_;
    for my $tag ( $this->tag_list ){
	$tag->set_readonly();
    }
    $this->{TLIST_READONLY} = 1;
}

=item spec

�������ʸ������Ѵ����롥

=cut
sub spec {
    my( $this ) = @_;
    join( '', map( $_->spec, $this->tag_list ) );
}

=item draw_tree

=item draw_tag_tree

������ΰ�¸�ط����ڹ�¤�Ȥ���ɽ�����ƽ��Ϥ��롥

=cut
sub draw_tag_tree {
    shift->draw_tree( @_ );
}

# draw_tree �᥽�åɤȤ��̿��ѤΥ᥽�åɡ�
sub draw_tree_leaves {
    shift->tag_list( @_ );
}

sub set_nodestroy {
    shift->{TLIST_NODESTROY} = 1;
}

=back

=head1 DESTRUCTOR

�������֥������ȴ֤˴ľ��Υ�ե���󥹤����������ȡ��̾�� Garbage
Collection �ˤ�äƤϥ��꤬�������ʤ��ʤ롥����������򤱤뤿��ˡ�
����Ū�˥�ե���󥹤��˲����� destructor ��������Ƥ��롥

=cut
sub DESTROY {
    my( $this ) = @_;
    unless( $this->{TLIST_NODESTROY} ){
	grep( ref $_ && $_->isa('KNP::Tag') && $_->DESTROY, $this->tag_list );
    }
}

=head1 SEE ALSO

=over 4

=item *

L<KNP::Tag>

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
