# $Id: Morpheme.pm,v 1.4 2007/03/02 15:18:37 ryohei Exp $
package KNP::Morpheme;
require 5.004_04; # For base pragma.
use strict;
use base qw/ KNP::Fstring KNP::KULM::Morpheme Juman::Morpheme /;
use vars qw/ @ATTRS /;
use Juman::Hinsi qw/ get_hinsi get_bunrui get_type get_form /;
use Encode;

=head1 NAME

KNP::Morpheme - �����ǥ��֥������� in KNP

=head1 SYNOPSIS

  $m = new KNP::Morpheme( "���� �������� ���� ̾�� 6 ����̾�� 2 * 0 * 0 NIL <ʸƬ>", 1 );

=head1 DESCRIPTION

�����ǤγƼ������ݻ����륪�֥������ȡ�

=head1 CONSTRUCTOR

=over 4

=item new ( SPEC, ID )

��1���� C<SPEC> �� KNP �ν��Ϥ��������ƸƤӽФ��ȡ����ιԤ����Ƥ����
����������������ǥ��֥������Ȥ��������롥

=cut

@ATTRS = ( 'fstring' );

sub _alt2spec {
    my( $str ) = @_;
    my( $midasi, $yomi, $genkei, $hinsi_id, $bunrui_id, $katuyou1_id, $katuyou2_id, $imis ) = split( '-', $str , 8);
    my $hinsi = &get_hinsi( $hinsi_id );
    my $bunrui = &get_bunrui( $hinsi_id, $bunrui_id );
    my $katuyou1 = &get_type( $katuyou1_id );
    my $katuyou2 = &get_form( $katuyou1_id, $katuyou2_id );
    if( utf8::is_utf8( $str ) ){
	$hinsi = decode('euc-jp', $hinsi);
	$bunrui = decode('euc-jp', $bunrui);
	$katuyou1 = decode('euc-jp', $katuyou1);
	$katuyou2 = decode('euc-jp', $katuyou2);
    }

    return join( ' ', $midasi, $yomi, $genkei, $hinsi, $hinsi_id, $bunrui, $bunrui_id, 
		 $katuyou1, $katuyou1_id, $katuyou2, $katuyou2_id, $imis );
}

sub new {
    my( $class, $spec, $id ) = @_;
    my $this = { id => $id };

    # ALT��ɸ���JUMAN�������Ѵ�����
    if ($spec =~ /^ALT-(.+)/){
	$spec = _alt2spec($1);
    }

    my @value;
    my( @keys ) = @Juman::Morpheme::ATTRS;
    push( @keys, @ATTRS );
    $spec =~ s/\s*$//;
    if( $spec =~ s/^\\ \\ \\ �ü� 1 ���� 6 // ){
	@value = ( '\ ', '\ ', '\ ', '�ü�', '1', '����', '6' );
	push( @value, split( / /, $spec, scalar(@keys) - 7 ) );
    } else {
#	@value = split( / /, $spec, scalar(@keys) );

	# ��̣�����""�Ǥ������Ƥ���
	
	# �ʲ��Τ褦�ʾ����б����뤿�������ɽ������

	# ���ä� ���ä� ���� ư�� 2 * 0 �Ҳ�ư���� 12 ���� 8 "��ɽɽ��:��" <��ɽɽ��:��><��ۣ><ALT-���ä�-���ä�-����-2-0-12-8-"��°ư�����ʴ��ܡ� ��ɽɽ��:�礦"><ALT-���ä�-���ä�-����-2-0-10-8-"��ʸ�� ��ɽɽ��:ͭ��"><����ۣ��><��ۣ-ư��><��ۣ-����¾><��°ư��������><���ʴ���><�Ҥ餬��><���Ѹ�><��Ω��><��Ω><����ñ�̻�><ʸ���>

	while ($spec =~ s/\"([^\"\s]+)(\s)([^\"]+)\"/\"$1\@\@$3\"/) {
	    ;
	}
	@value = split( / /, $spec);
	$value[11] =~ s/\@\@/ /g;
	$value[12] =~ s/\@\@/ /g;

#	@value = &quotewords(" ", 1, $spec);
    }
    while( @keys and @value ){
	my $key = shift @keys;
	$this->{$key} = shift @value;
    }

    &KNP::Fstring::fstring( $this, $this->{fstring} );
    bless $this, $class;
}

=back

=head1 METHODS

L<Juman::Morpheme> �γƥ᥽�åɤ˲ä��ơ�KNP �ˤ�äƳ�����Ƥ�줿��
ħʸ����򻲾Ȥ��뤿��Υ᥽�åɤ����Ѳ�ǽ�Ǥ��롥

=over 4

=item fstring

��ħʸ������֤���

=item feature

��ħ�Υꥹ�Ȥ��֤���

=item push_feature

��ħ���ɲä��롥

=back

�����Υ᥽�åɤξܺ٤ˤĤ��Ƥϡ�L<KNP::Fstring> �򻲾ȤΤ��ȡ����ˡ�
�ʲ��Υ᥽�åɤ����Ѳ�ǽ�Ǥ��롥

=over 4

=item repname

�����Ǥ���ɽɽ�����֤���

=cut

sub repname {
    my ( $this ) = @_;

    my $result = $this->Juman::Morpheme::repname;
    return $result if ( defined $result );

    my $pat = '(����)��ɽɽ��';
    if( utf8::is_utf8( $this->midasi ) ){
	$pat = decode('euc-jp', $pat);
    }

    if ( defined $this->{fstring} ){
	if ($this->{fstring} =~ /<$pat:([^\>]+)>/){
	    return $2;
	}
    }
    return undef;
}

=back

=item spec

�����Ǥ����Ƥν�����ؼ�����ʸ������������롥KNP �ν��Ϥ�1�Ԥ�������
�롥

=cut

sub spec {
    my( $this ) = @_;
    sprintf( "%s\n", join( ' ', map( $this->{$_}, ( @Juman::Morpheme::ATTRS, @ATTRS ) ) ) );
}

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::Fstring>

=item *

L<Juman::Morpheme>

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
