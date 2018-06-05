# $Id: Simple.pm,v 1.2 2006/10/31 08:46:56 shibata Exp $
package KNP::Simple;
require 5.004_04; # For base pragma.
use KNP;
use strict;
use base qw/ Exporter /;
use vars qw/ @EXPORT /;
@EXPORT = qw/ knp /;

=head1 NAME

KNP::Simple - ��ʸ���Ϥ�Ԥ��⥸�塼��

=head1 DESCRIPTION

C<KNP::Simple> �ϡ�KNP ���Ѥ��ƹ�ʸ���Ϥ�Ԥ��ؿ� C<knp> ����������
���塼��Ǥ��롥

���Υ⥸�塼���Ȥ��ȡ�C<KNP> �⥸�塼����ñ�ˡ����������¤��줿��
�����Ѥ��뤳�Ȥ��Ǥ��롥�㤨�С����Υ⥸�塼��ϡ��ǽ�˺������� 
C<KNP> ���֥������Ȥ�����Ѥ���Τǡ����ץ����������ѹ��ʤɤϤǤ���
���������٤�����ǹ�ʸ���Ϥ�Ԥ�ɬ�פ�������ϡ�C<KNP> �⥸�塼��
��ľ�ܸƤӽФ����ȡ�

=head1 FUNCTION

=over 4

=item knp ($str)

���ꤵ�줿ʸ������оݤȤ��ƹ�ʸ���Ϥ�Ԥ��ؿ���C<KNP::Result> ���֥���
���Ȥ��֤���

  Example:

    use KNP::Simple;
    $result = &knp( "����ʸ��ʸ���Ϥ��Ƥ���������" );
    print $result->all();

��ʸ���ϤΥ��ץ������ѹ�������ϡ�C<use> �λ����ǻ��ꤷ�Ƥ�����

  Example:

    use KNP::Simple -Option => "-tab -case2";
    $result = &knp( "����ʸ��ʸ���Ϥ��Ƥ���������" );
    print $result->all();

���ץ����ˤϡ�C<KNP::new> �μ����դ��륪�ץ�����Ʊ����Τ�����Ǥ�
�롥

=cut
my @OPTION;
my $KNP;

sub import {
    my $class = shift;
    @OPTION = @_;
    $class->export_to_level( 1 );
}

sub knp {
    my( $str ) = @_;
    $KNP ||= KNP->new( @OPTION );
    $KNP->parse( $str );
}

1;

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP>

=item *

L<KNP::Result>

=back

=head1 AUTHOR

=over 4

=item
�ڲ� ��̭ <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=cut

__END__
# Local Variables:
# mode: perl
# coding: euc-japan
# use-kuten-for-period: nil
# use-touten-for-comma: nil
# End:
