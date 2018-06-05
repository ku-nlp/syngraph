# $Id: Tag.pm,v 1.2 2006/10/31 08:53:09 shibata Exp $
package KNP::Tag;
require 5.004_04; # For base pragma.
use KNP::Morpheme;
use strict;
use base qw/ KNP::Depend KNP::Fstring Juman::MList /;

=head1 NAME

KNP::Tag - �������֥������� in KNP

=head1 SYNOPSIS

  $b = new KNP::Tag( "+ 1D <���ϳ�-��>", 0 );

=head1 DESCRIPTION

�ʲ��Ϥ�ñ�̤Ȥʤ륿���γƼ������ݻ����륪�֥������ȡ�

=head1 CONSTRUCTOR

=over 4

=item new ( SPEC, ID )

��1���� C<SPEC> �� KNP �ν��Ϥ��������ƸƤӽФ��ȡ����ιԤ����Ƥ����
�����������륿�����֥������Ȥ��������롥

=cut
sub new {
    my( $class, $spec, $id ) = @_;
    my $new = bless( {}, $class );

    $spec =~ s/\s*$//;
    if( $spec eq '+' ){
	$new->id( $id );
    } elsif( my( $parent_id, $dpndtype, $fstring ) = ( $spec =~ m/^\+ (-?\d+)(\w)(.*)$/ ) ){
	$new->id( $id );
	$new->dpndtype( $dpndtype );
	$new->parent_id( $parent_id );
	$new->fstring( $fstring );
    } else {
	die "KNP::Tag::new(): Illegal spec = $spec\n";
    }
    $new;
}

=back

=head1 METHODS

1�ĤΥ����ϡ�ʣ���η����Ǥ���ʤ롥�������äơ��������֥������Ȥϡ���
�����󥪥֥������� C<Juman::MList> ��Ѿ�����褦�˼������졤��������
����Ф������ C<mrph> �᥽�åɤ����Ѳ�ǽ�Ǥ��롥

�����֤ΰ�¸�ط��˴ؤ��������ݻ������뤿��ˡ�C<KNP::Depend> ��
�饹��Ѿ����Ƥ��롥�������äơ��ʲ��Υ᥽�åɤ����Ѳ�ǽ�Ǥ��롥

=over 4

=item parent

�����西�����֤���

=item child

���Υ����˷��äƤ��륿���Υꥹ�Ȥ��֤���

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

�������֥������Ȥ�ʸ������Ѵ����롥

=cut
sub spec {
    my( $this ) = @_;
    sprintf( "+ %d%s %s\n%s",
	     $this->parent() ? $this->parent->id() : -1,
	     $this->dpndtype(),
	     $this->fstring(),
	     $this->SUPER::spec() );
}

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::Depend>

=item *

L<KNP::Fstring>

=item *

L<Juman::MList>

=item *

L<KNP::Morpheme>

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
