# $Id: Bunsetsu.pm,v 1.2 2006/10/31 08:53:08 shibata Exp $
package KNP::Bunsetsu;
require 5.004_04; # For base pragma.
use Carp;
use KNP::Morpheme;
use strict;
use base qw/ KNP::Depend KNP::Fstring KNP::TList KNP::KULM::Bunsetsu Juman::MList /;

=head1 NAME

KNP::Bunsetsu - ʸ�ᥪ�֥������� in KNP

=head1 SYNOPSIS

  $b = new KNP::Bunsetsu( "* -1D <BGH:����>" );

=head1 DESCRIPTION

KNP �ˤ�뷸��������Ϥ�ñ�̤Ǥ���ʸ��γƼ������ݻ����륪�֥������ȡ�

=head1 CONSTRUCTOR

=over 4

=item new ( SPEC, ID )

��1���� C<SPEC> �� KNP �ν��Ϥ��������ƸƤӽФ��ȡ����ιԤ����Ƥ����
������������ʸ�ᥪ�֥������Ȥ��������롥

=cut
sub new {
    my( $class, $spec, $id ) = @_;
    my $new = bless( {}, $class );

    $spec =~ s/\s*$//;
    if( $spec eq '*' ){
	$new->id( $id );
    } elsif( my( $parent_id, $dpndtype, $fstring ) = ( $spec =~ m/^\* (-?\d+)([DPIA])(.*)$/ ) ){
	$new->id( $id );
	$new->parent_id( $parent_id );
	$new->dpndtype( $dpndtype );
	$new->fstring( $fstring );
    } else {
	die "KNP::Bunsetsu::new(): Illegal spec = $spec\n";
    }
    $new;
}

=back

=head1 METHODS

1�Ĥ�ʸ���ʣ���η����Ǥ���ʤ뤿�ᡤʸ�ᥪ�֥������ȤϷ������󥪥֥���
���� C<Juman::MList> ��Ѿ����Ƥ��롥�������äơ������������Ф���
��� C<mrph> �᥽�åɤ����Ѳ�ǽ�Ǥ��롥

�ޤ����ʲ��Ϥ�Ԥä����ϡ�1�Ĥ�ʸ�᤬ʣ���Υ�������ʤ���⤢�롥
���Τ��ᡤʸ�ᥪ�֥������Ȥϥ����󥪥֥������� C<KNP::TList> ��Ѿ�����
�����Υꥹ�Ȥ���Ф������ C<tag> �᥽�åɤ����Ѳ�ǽ�Ǥ��롥

=over 4

=item mrph_list

ʸ��˴ޤޤ�����Ƥη����Ǥ��֤���

=cut
sub mrph_list {
    my $this = shift;
    if( $this->tag ){
	$this->KNP::TList::mrph_list( @_ );
    } else {
	$this->Juman::MList::mrph_list( @_ );
    }
}

=item push_mrph ( @MRPH )

���ꤵ�줿�����Ǥ�ʸ����ɲä��롥

=cut
sub push_mrph {
    my $this = shift;
    if( $this->tag ){
	$this->KNP::TList::push_mrph( @_ );
    } else {
	$this->Juman::MList::push_mrph( @_ );
    }
}

=item push_tag ( @TAG )

���ꤵ�줿������ʸ����ɲä��롥

=cut
sub push_tag {
    my $this = shift;
    if( $this->Juman::MList::mrph_list ){
	# ����ʸ��ˤϡ������˴ޤޤ�Ƥ��ʤ������Ǥ�����¸�ߤ��Ƥ����
	# �ǡ��ǡ�����̷��������������ǽ�������롥
	carp "Unsafe addition of tags";
    }
    $this->KNP::TList::push_tag( @_ );
}

=back

ʸ��֤ΰ�¸�ط��˴ؤ��������ݻ������뤿��ˡ�C<KNP::Depend> ��
�饹��Ѿ����Ƥ��롥�������äơ��ʲ��Υ᥽�åɤ����Ѳ�ǽ�Ǥ��롥

=over 4

=item parent

������ʸ����֤���

=item child

����ʸ��˷��äƤ���ʸ��Υꥹ�Ȥ��֤���

=item dpndtype

��������ط��μ���(D,P,I,A)���֤���

=item id

���󥹥ȥ饯����ƤӽФ��Ȥ��˻��ꤵ�줿 ID ���֤���̵����ξ��� -1 
���֤���

=back

KNP �ˤ�äƳ�����Ƥ�줿��ħʸ������ݻ������Ȥ��뤿��ˡ�
C<KNP::Fstring> ���饹��Ѿ����Ƥ��롥�������äơ��ʲ��Υ᥽�åɤ�����
��ǽ�Ǥ��롥

=over 4

=item fstring

��ħʸ������֤���

=item feature

��ħ�Υꥹ�Ȥ��֤���

=item push_feature

��ħ���ɲä��롥

=back

�ä��ơ��ʲ��Υ᥽�åɤ��������Ƥ��롥

=over 4

=item spec

ʸ�ᥪ�֥������Ȥ�ʸ������Ѵ����롥

=cut
sub spec {
    my( $this ) = @_;
    sprintf( "* %d%s %s\n%s",
	     $this->parent() ? $this->parent->id() : -1,
	     $this->dpndtype(),
	     $this->fstring(),
	     ( $this->tag ? $this->KNP::TList::spec() : $this->Juman::MList::spec() ) );
}

=back

=head1 DESTRUCTOR

ʸ�ᥪ�֥������Ȥϡ��ǥ��ȥ饯����������Ƥ���2����Υ��֥������� 
C<KNP::Depend>, C<KNP::TList> ��Ѿ����Ƥ��롥ξ���Υǥ��ȥ饯���򤭤�
��ȸƤӽФ��ʤ��ȡ�����꡼���θ����Ȥʤ롥

=cut
sub DESTROY {
    my( $this ) = @_;
    $this->KNP::TList::DESTROY();
    $this->KNP::Depend::DESTROY();
}

=head1 SEE ALSO

=over 4

=item *

L<KNP::Depend>

=item *

L<KNP::Fstring>

=item *

L<KNP::TList>

=item *

L<Juman::MList>

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
